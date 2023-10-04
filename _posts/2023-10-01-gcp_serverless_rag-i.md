---
layout: post
comments: true
title: Serverless RAG applications on GCP - Part 1
excerpt: Learn how to deploy Serverless Retrieval augmented generation (RAG) applications on GCP with Vertex AI and LangChain
tags: [ai,gcp,genai]
toc: true
img_excerpt:
---

![GCP Serverless RAG architecture]({{ "/assets/2023/10/20231001-gcp-serverless-rag.svg" | absolute_url }})

## Infrastructure

### Cloud Storage
We need to setup a Cloud Storage bucket, let's first define some environment variables

```shell
PROJECT_ID = ""
REGION = ""
SERVICE_ACCOUNT = "rag-identity"
BUCKET = "documents-bucket"
```

Create a Cloud Storage bucket or reuse an existing one:
```shell
gsutil mb -l $REGION gs://$BUCKET
```

Create a service account to serve as the service identity:
```shell
gcloud iam service-accounts create $SERVICE_ACCOUNT
```

Grant the service account access to the Cloud Storage bucket:
```shell
gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member "serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
     --role "roles/storage.objectAdmin"
```

### PubSub
Within Pub/Sub, a topic is a named resource that represents a feed of messages. You must create a topic before you can publish or subscribe to it.

This document describes how to create a Pub/Sub topic. To create a topic you can use the Google Cloud console, the Google CLI, the client library, or the Pub/Sub API.

```shell
TOPIC = "documents-upload-topic"
```

```shell
gcloud pubsub topics create $TOPIC
```

Using `gsutil`, we can create such a notification rule by providing the source bucket to be notified when files are uploaded to it, and specifying the destination PubSub queue where notifications will be sent. This is an example configuration:

```shell
gsutil notification create -t $TOPIC -f json -e OBJECT_FINALIZE gs://$BUCKET
```

### Cloud SQL

```shell
INSTANCE_NAME = "vectorstore"
DATABASE_NAME = "documents"
DATABASE_USER = "admin"
DATABASE_PASSWORD = "YOUR_PASSWORD"
```

```shell
# Creating new Cloud SQL instance
gcloud sql instances create $INSTANCE_NAME --database-version=POSTGRES_15 \
  --region=$REGION --cpu=1 --memory=4GB --root-password=$DATABASE_PASSWORD

# Create the database, if it does not exist.
gcloud sql databases create $DATABASE_NAME --instance=$INSTANCE_NAME

# Create the database user for accessing the database.
gcloud sql users create $DATABASE_USER \
  --instance=$INSTANCE_NAME \
  --password=$DATABASE_PASSWORD

# Enable Cloud SQL Admin API
gcloud services enable sqladmin.googleapis.com
gcloud services enable aiplatform.googleapis.com
```


Grant the service account access to the Cloud Storage bucket:
```shell
gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member "serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
     --role "roles/cloudsql.client"
```

## Embedding the documents

### Dockerfile


```Dockerfile
FROM python:3.9-slim

# Ensure stdout/stderr are not buffered.
ENV PYTHONUNBUFFERED TRUE

# Create a user to run the cloud function
RUN groupadd -g 1000 userweb && useradd -r -u 1000 -g userweb userweb

ENV APP_HOME /app
WORKDIR $APP_HOME

RUN chown userweb:userweb $APP_HOME

USER userweb

# Copy local code to the container image.
COPY . ./

# Install production dependencies.
RUN pip install -r requirements.txt

# Run the cloud function
CMD ["functions-framework", "--target=cloudevent_handler", "--signature-type=cloudevent"]
```

`requirements.txt`

```
cloudevents
functions_framework=3.*
asyncio==3.4.3
asyncpg==0.27.0
cloud-sql-python-connector["asyncpg"]==1.2.3
pgvector==0.1.8
langchain==0.0.196
transformers==4.30.1
google-cloud-aiplatform==1.26.0
google-cloud-storage
```

- https://cloud.google.com/sql/docs/postgres/connect-functions
- https://cloud.google.com/sql/docs/postgres/connect-instance-cloud-functions
- https://codelabs.developers.google.com/codelabs/connecting-to-cloud-sql-with-cloud-functions

## Vector Embeddings

### Read file

- https://cloud.google.com/storage/docs/downloading-objects

```python
from google.cloud import storage


def download_blob(bucket_name, source_blob_name, destination_file_name):
    """Downloads a blob from the bucket."""
    # The ID of your GCS bucket
    # bucket_name = "your-bucket-name"

    # The ID of your GCS object
    # source_blob_name = "storage-object-name"

    # The path to which the file should be downloaded
    # destination_file_name = "local/path/to/file"

    storage_client = storage.Client()

    bucket = storage_client.bucket(bucket_name)

    # Construct a client side representation of a blob.
    # Note `Bucket.blob` differs from `Bucket.get_blob` as it doesn't retrieve
    # any content from Google Cloud Storage. As we don't need additional data,
    # using `Bucket.blob` is preferred here.
    blob = bucket.blob(source_blob_name)
    blob.download_to_filename(destination_file_name)

    print(
        "Downloaded storage object {} from bucket {} to local file {}.".format(
            source_blob_name, bucket_name, destination_file_name
        )
    )
```

### Generate vector embeddings using a Text Embedding model

Step 1: Split long product description text into smaller chunks

- The product descriptions can be much longer than what can fit into a single API request for generating the vector embedding.

- For example, Vertex AI text embedding model accepts a maximum of 3,072 input tokens for a single API request.

- Use the `RecursiveCharacterTextSplitter` from LangChain library to split
the description into smaller chunks of 500 characters each.

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

# Split long text descriptions into smaller chunks that can fit into
# the API request size limit, as expected by the LLM providers.
def chunk(document)
  text_splitter = RecursiveCharacterTextSplitter(
    separators=[".", "\n"],
    chunk_size=500,
    chunk_overlap=0,
    length_function=len,
  )
  splits = text_splitter.create_documents([document])
  chunks = [{"content": s.page_content} for s in splits]
  return chunks
```

Step 2: Generate vector embedding for each chunk by calling an Embedding Generation service

- In this demo, Vertex AI text embedding model is used to generate vector embeddings, which outputs a 768-dimensional vector for each chunk of text.

>⚠️ The following code snippet may run for a few minutes.

```python
from langchain.embeddings import VertexAIEmbeddings
from google.cloud import aiplatform

project_id = os.environ["PROJECT_ID"]
region = os.environ["REGION"]

# Generate the vector embeddings for each chunk of text.
def embed(chunks, batch_size = 5):
  # Initialize Vertex AI Embedding Service
  aiplatform.init(project=project_id, location=region)
  embeddings_service = VertexAIEmbeddings()
  # Embed all chunks in batches
  for i in range(0, len(chunks), batch_size):
    request = [x["content"] for x in chunks[i : i + batch_size]]
    response = embeddings_service.embed_documents(request)
    # Store the retrieved vector embeddings for each chunk back.
    for x, e in zip(chunks[i : i + batch_size], response):
      x["embedding"] = e
```

### Use pgvector to store the generated embeddings within PostgreSQL

- The `pgvector` extension introduces a new `vector` data type.
- **The new `vector` data type allows you to directly save a vector embedding (represented as a NumPy array) through a simple INSERT statement in PostgreSQL!**

>⚠️ The following code snippet may run for a few minutes.

```python
# Save the Pandas dataframe in a PostgreSQL table.
import os
import asyncio
import asyncpg
from google.cloud.sql.connector import Connector
from pgvector.asyncpg import register_vector

# Cloud SQL instance connection name
db_host = os.environ["INSTANCE_CONNECTION_NAME"]  # e.g. project:region:instance
db_user = os.environ["DB_USER"]  # e.g. 'my-db-user'
db_pass = os.environ["DB_PASS"]  # e.g. 'my-db-password'
db_name = os.environ["DB_NAME"]  # e.g. 'my-database'
ip_type = IPTypes.PRIVATE if os.environ.get("PRIVATE_IP") else IPTypes.PUBLIC

# Save a list of (content, embedding) into Cloud SQL
async def save(chunks):
  loop = asyncio.get_running_loop()
  async with Connector(loop=loop) as connector:
    # Create connection to Cloud SQL database
    conn: asyncpg.Connection = await connector.connect_async(
      db_host,
      "asyncpg",
      user=db_user,
      password=db_pass,
      db=db_name,
      ip_type=ip_type,
    )

    # Load the pgvector extension
    await conn.execute("CREATE EXTENSION IF NOT EXISTS vector")
    await register_vector(conn)

    # Create the `document_embeddings` table.
    await conn.execute(
      """CREATE TABLE IF NOT EXISTS document_embeddings(
            id VARCHAR(1024) PRIMARY KEY,
            content TEXT,
            embedding VECTOR(768))"""
    )
    # Insert rows to the `document_embeddings` table.
    rows = [(x["content"], x["embedding"]) for x in chunks]
    await conn.execute(
      "INSERT INTO document_embeddings (content, embedding) VALUES ($1, $2)",
      rows,
    )
    await conn.close()
```

> Note: Saving credentials in environment variables is convenient, but not secure - consider a more secure solution such as [Cloud Secret Manager](https://cloud.google.com/secret-manager) to help keep secrets safe. Alternatively [Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/connect-instance-auth-proxy)

`main.py`

```python
import os
from cloudevents.http import CloudEvent
import functions_framework
from lib import chunk, embed, save

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT")

def cloudevent_handler(cloud_event: CloudEvent) -> None:
    print(f"Received event with ID: {cloud_event['id']} and data {cloud_event.data}")
    # Get the bucket and file name from the event.
    data = cloud_event.data["message"]["data"]
    gs_uri = f"gs://{data["bucket"]}/{data["name"]}"
    # TODO Read the file from GS
    document = 
    # Chunk the document
    chunks = chunk(document)
    # Embed all chunks
    embed(chunks)
    # Save in PG
    save(chunks)

if __name__ == "__main__":
  # Register the function with the Functions Framework.
  functions_framework.cloud_event(cloudevent_handler)
```

Finally, we can deploy our Cloud Function using the `gcloud` CLI from the same directory containing the source code as follows

```shell
gcloud functions deploy minutes-function \
  --gen2 \
  --runtime python39 \
  --entry-point cloudevent_handler \
  --source . \
  --region $REGION \
  --trigger-topic $TOPIC
```


## Cloud Run
Finally, we can deploy the container image to Cloud Run using `gcloud`:

- We are not building the image but relying on Cloud Run instead as we deploy the current directory as the source code.
- We are using Cloud Run service Gen 2 by setting the `--execution-environment` flag
- For testing, we allow unauthenticated access to the service via `--allow-unauthenticated`
- We use same service account used when creating Cloud Storage bucket in `--service-account`
- We pass the name of the bucket via `--update-env-vars` flag as an environment variable 



Run the following `gcloud artifacts repositories create` command in Cloud Shell to create a repository in the Artifact Registry named quickstart-repo in the same region as your Cloud SQL instance. Replace YOUR_PROJECT_ID with your project ID and YOUR_REGION_NAME with your region name.

```shell
gcloud artifacts repositories create rag-repo \
  --project=$PROJECT_ID \
  --repository-format=docker \
  --location=$REGION \
  --description="Artifacts for RAG applications"
```

Run the `gcloud builds submit` command as follows in Cloud Shell to build a Docker container and publish it to Artifact Registry. Replace YOUR_PROJECT_ID with your project ID and YOUR_REGION_NAME with your region name.

```shell
gcloud builds submit \
  --tag $REGION-docker.pkg.dev/$PROJECT_ID/quickstart-repo/embed-function .
```

Finally, we can deploy our Cloud Function using the `gcloud` CLI from the same directory containing the source code as follows

```shell
gcloud functions deploy embed-function --source . \
  --execution-environment gen2 \
  --runtime python39 \
  --entry-point cloudevent_handler \
  --region $REGION \
  --trigger-topic $TOPIC
  --service-account $SERVICE_ACCOUNT \
  --update-env-vars BUCKET=$BUCKET \
  --update-env-vars INSTANCE_CONNECTION_NAME=$PROJECT_ID:$REGION:$INSTANCE_NAME
```


After deployment finishes and the service becomes available, we can test it with the following `curl`
```shell
curl -X POST -H "Content-Type: text/plain" -d "Tell me a joke" https://my-service-abcdef-uc.a.run.app
```

## That's all folks
In this article we saw how easy it is to use Google Cloud Run to package LLM applications, and leaverage Cloud Storage to store the weights once and for all.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
