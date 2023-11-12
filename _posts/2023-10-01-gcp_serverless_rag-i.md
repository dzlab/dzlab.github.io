---
layout: post
comments: true
title: Scalable RAG applications on GCP with Serverless architecture - Part 1
excerpt: Learn how to deploy a scalable Retrieval augmented generation (RAG) applications on GCP with a Serverless architecture
tags: [ai,gcp,genai]
toc: true
img_excerpt:
---

![GCP Serverless RAG architecture]({{ "/assets/2023/10/20231001-gcp-serverless-rag.svg" | absolute_url }})


Retrieval-Augmented Generation (RAG) is an AI framework that enhances the quality of Large Language Model (LLM)-generated responses by supplementing the LLM's internal representation of information with external sources of knowledge. This gives us control over the data used by the LLM when it formulates a response. With RAG, we can constrain the external information accessible to the LLM to include any type of vectorized data: documents, images, audio, and video. 

This serie of articles showcase how to leverage GCP managed services to implement Retrieval-Augmented workflows at Scale. In this first part, we will develop a serverless ETL data pipeline to extract, embed, index business documents of any scale. We will leaverage **LangChain** for chunking large documents into small chunks, **Vertex AI** for data indexing and **Cloud SQL for Postgres** and its **pgvector** extension as a managed vector store. To be able to scale the data pipeline up or down based on the amount of documents while controlling cost we will use **Cloud Functions**.
In the second part, we will implement a serverless data retrieval by leaveraging **Cloud Run** as a scalable runtime and **LangChain** to construct Question/Answering prompts from user input in a format that maximizes the LLM response accuracy.


## Infrastructure

The diagram above illustrates the architecture and components of the solution. It shows the process of uploading a document to cloud storage, the document being processed and saved with embeddings, and the user querying and searching for the document using embeddings.

The solution is divided into 10 steps:

- Steps 1 to 6 represents the ETL Data pipeline
- Steps 7 to 10 represents the user query flow

In the remaining of this first part, we will implement the steps of the ETL Data pipeline.


### Cloud Storage
First, we need to setup a Cloud Storage bucket where the data will be uploaded for processing.

Let's first define some environment variables

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

Create a service account to use as the service identity:
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
Once documents are uploaded to Cloud Storage, we want a notification event to be created and queued in a PubSub topic.

Let's create a PubSub topic with the Google CLI.

```shell
TOPIC = "documents-upload-topic"

gcloud pubsub topics create $TOPIC
```

Then, using `gsutil`, we create a notification rule on the source bucket to be notified when files are uploaded to this bucket, and specifying the destination PubSub queue where notifications will be sent.

```shell
gsutil notification create -t $TOPIC -f json -e OBJECT_FINALIZE gs://$BUCKET
```

### Cloud SQL
Cloud SQL for PostgreSQL supports the [pgvector](https://github.com/pgvector/pgvector) extension that brings the power of vector search operations to PostgreSQL. This extension is not enabled by default, but we can activate it by simply running the following SQL query:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

Once pgvector is enabled, a new data type called `vector` becomes available to use with PostgreSQL table columns. Using the `vector` data type we can directly save embeddings like we would do with any other PostgreSQL data type. Learn more about using pgvector with Cloud SQL for Postgres - [link](https://cloud.google.com/blog/products/databases/using-pgvector-llms-and-langchain-with-google-cloud-databases/).


Let's create a PosgreSQL instance to store the documents chunks and their embeddings:

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

## Serverless data pipeline

The data pipeline, responsible for ingesting/processing/storing documents, is implemented as a Cloud Function.

Let's first define the dependencies in a `requirements.txt` file

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

The rest of this section, describes the detailed implementation of each component of the data pipeline.

> Note: all helper functions are stored in the `lib.py` file

### Reading from Cloud Storage
This is a helper function to read a file from Cloud Storage (see [documentation](https://cloud.google.com/storage/docs/downloading-objects)), to be used in our Cloud Function to download documents.

```python
from google.cloud import storage

def download(bucket_name, source_blob_name, destination_file_name):
  """Downloads a blob from GS bucket."""
  storage_client = storage.Client()
  bucket = storage_client.bucket(bucket_name)
  blob = bucket.blob(source_blob_name)
  blob.download_to_filename(destination_file_name)
```

### Chunking with LangChain
The ingested documents can be much longer than what can fit into a Vertex AI request for generating the vector embedding. In fact, Vertex AI text embedding model accepts text of size up to 3,072.

This helper function uses the `RecursiveCharacterTextSplitter` from the LangChain library to split a document into smaller chunks of 1024 characters each.

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

# Split long text descriptions into smaller chunks that can fit into
# the API request size limit, as expected by the LLM providers.
def chunk(document)
  text_splitter = RecursiveCharacterTextSplitter(
    separators=[".", "\n"],
    chunk_size=1024,
    chunk_overlap=0,
    length_function=len,
  )
  splits = text_splitter.create_documents([document])
  chunks = [{"content": s.page_content} for s in splits]
  return chunks
```

### Text embedding with Vertex AI
This helper function uses Vertex AI text embedding model to generate vector embeddings, which are a 768-dimensional vectors. It takes a list of document chunks and calls Vertex AI Embedding Generation service with a batch of chunks each time, then adds the embeddings to each chunk's object using the key `"embedding"`.


```python
from langchain.embeddings import VertexAIEmbeddings
from google.cloud import aiplatform

project_id = os.environ["PROJECT_ID"]
region = os.environ["REGION"]

# Generate the vector embeddings for each chunk of text.
def embed(chunks, batch_size = 3):
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

### Saving to PostgreSQL
This helper function uses the [Cloud SQL Python Connector](https://cloud.google.com/sql/docs/postgres/samples/cloud-sql-postgres-sqlalchemy-connect-connector) to connect to the Cloud SQL from our Cloud Function. Then makes sure the `pgvector` extension is loaded and the target embeddings table is created. Finally, writes the chunks with their embeddings into Cloud SQL.

```python
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

    # Create the `document_embeddings` table (it does not exist yet)
    await conn.execute(
      """CREATE TABLE IF NOT EXISTS document_embeddings(
            id BIGSERIAL PRIMARY KEY,
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

> Note: Saving credentials in environment variables is convenient, but not secure - consider a more secure solution such as [Cloud Secret Manager](https://cloud.google.com/secret-manager) to help keep secrets safe. Alternatively [Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/connect-instance-auth-proxy).

### All together
Finally, we implement the event handling of our Cloud Function in `main.py`. Upon receiving a notification event related to a file upload, we download the file, chunk it, embed each chunk, then store the embeddings to Cloud SQL.

```python
from cloudevents.http import CloudEvent
import functions_framework
from lib import download, chunk, embed, save

def cloudevent_handler(cloud_event: CloudEvent) -> None:
    print(f"Received event with ID: {cloud_event['id']} and data {cloud_event.data}")
    # Get the bucket and file name from the event.
    data = cloud_event.data["message"]["data"]
    # Download the file from GS
    download(data["bucket"], data["name"], 'blob.txt')
    # Read local file
    document = open('blob.txt', 'r').read()
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

## Deploy to Cloud Function
First, we create a repository in the Artifact Registry to host the Docker containers of our Cloud Function (see [documentation](https://cloud.google.com/sql/docs/postgres/connect-instance-cloud-functions)).

```shell
gcloud artifacts repositories create rag-repo \
  --project=$PROJECT_ID \
  --repository-format=docker \
  --location=$REGION \
  --description="Artifacts for RAG applications"
```

We can optionally build Docker container of our Cloud Function and publish it to the Artifact Registry we created earlier.

```shell
gcloud builds submit \
  --tag $REGION-docker.pkg.dev/$PROJECT_ID/rag-repo/index-function .
```

Finally, we deploy our Cloud Function using the `gcloud` CLI from the same directory containing the source code as follows

```shell
gcloud functions deploy index-function --source . \
--execution-environment gen2 \
--runtime python39 \
--entry-point cloudevent_handler \
--region $REGION \
--trigger-topic $TOPIC
--service-account $SERVICE_ACCOUNT \
--set-env-vars BUCKET=$BUCKET \
--set-env-vars INSTANCE_CONNECTION_NAME=$PROJECT_ID:$REGION:$INSTANCE_NAME
```


## That's all folks
Building RAG applications to query bunch of files on your local machine is straightforward, however building a scalable and reliable architecture for RAG to ingest and query large amount of data is no easy business. In this article, we saw how to leverage Google Cloud managed services to build a serverless large-scale data pipeline to ingest and process data on the fly. In a next article, we will continue with our serverless approach and implemenet a scalable retrieval system, stay tuned.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
