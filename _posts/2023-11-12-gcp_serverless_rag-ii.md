---
layout: post
comments: true
title: Scalable RAG applications on GCP with Serverless architecture - Part 2
excerpt: Learn how to deploy a scalable Retrieval augmented generation (RAG) applications on GCP with a Serverless architecture
tags: [ai,gcp,genai]
toc: true
img_excerpt:
---

![GCP Serverless RAG architecture]({{ "/assets/2023/10/20231001-gcp-serverless-rag.svg" | absolute_url }})

In a [previous article]({{ "2023/10/01/gcp_serverless_rag-i/" }}), we built a serverless data pipeline to make an entire dataset searchable using simple English. In this second part, we will build a query anwering pipeline as represented by the Steps 7 to 10 in the diagram above. We will leverage **pgvector** Cosine search operator to filter documents from our dataset and **Vertex AI** with **LangChain** to generate a final answer based on the selected subset of documents.

## Serverless Query Answering
In this section, we define a set of helper functions to implement each component of the Query Answering pipeline in the `lib.py` file.

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

### Embed the query

Next, we define a helper function to generate the vector embedding for the user query.

```python
from langchain.embeddings import VertexAIEmbeddings

# Generate embedding for the user query
def embed_query(user_query):
    embeddings_service = VertexAIEmbeddings()
    return embeddings_service.embed_query([user_query])
```

> To learn more about using **Vertex AI** for retrieval check the following [article](https://cloud.google.com/blog/products/databases/using-pgvector-llms-and-langchain-with-google-cloud-databases/)

### Retrive the documents

To filter documents from our dataset we use the pgvector cosine similarity search operator. The following helper function establish a connection to PostgreSQL and then submits a retrieval query that uses the Cosine operator `<=>`:


```python
import os
import asyncio
import asyncpg
from google.cloud.sql.connector import Connector

# Cloud SQL instance connection name
db_host = os.environ["INSTANCE_CONNECTION_NAME"]  # e.g. project:region:instance
db_user = os.environ["DB_USER"]  # e.g. 'my-db-user'
db_pass = os.environ["DB_PASS"]  # e.g. 'my-db-password'
db_name = os.environ["DB_NAME"]  # e.g. 'my-database'
ip_type = IPTypes.PRIVATE if os.environ.get("PRIVATE_IP") else IPTypes.PUBLIC

# Find the documents most closely related to the input query.
def retrieve(query_embedding, similarity_threshold=0.8, num_matches=3):
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

        # Use cosine similarity search to find documents
        results = await conn.fetch("""
            SELECT content
            FROM document_embeddings
            WHERE 1 - (embedding <=> $1) > $2
            LIMIT $3
            """, 
            query_embedding, similarity_threshold, num_matches)
        await conn.close()

  return results
```

### Answer user query
Next, we use **LangChain** to answer the user query. After filtering documents from the dataset to only relevant ones using `pgvector`, the next step is to add them to the prompt input for the VertexAI LLM model and to ask the model to answer the user query. This is simply done with LangChain's Question Answering Chain as follows:

```python
from langchain.chains.qa_with_sources import load_qa_with_sources_chain
from langchain.docstore.document import Document
from langchain.llms import VertexAI

def qa(matches, question):
    llm = VertexAI()
    chain = load_qa_with_sources_chain(llm)
    documents = [Document(page_content=text) for text in matches]
    inputs = {"input_documents": documents, "question": question}
    outputs = chain(inputs, return_only_outputs=True)["output_text"]
    return outputs
```

> To learn more about using **LangChain** for Question Answering check the following [article](https://dzlab.github.io/2023/01/02/prompt-langchain/)

### All together
Finally, we create a simple Flask based API to answer user queries. Upon receiving a user request with a question, we embed the question, use the embeddings to filter out non relevant documents, then pass the selected documents along with the user query to an LLM to generate a response.

```python
import os
from flask import Flask, request
from lib import embed_query, retrieve, qa

@app.route('/answer', methods= ['POST'])
def answer():
    # Get the user query
    user_query = request.data
    # Embed user query
    embed_query(user_query)
    # Retrieve similar documents
    matches = retrieve(query_embedding)
    # Answer the query given found matches
    response = qa(matches, user_query)
    return response

if __name__ == "__main__":
    app.run(port=8000, host='0.0.0.0', debug=True)
```


## Deploy to Cloud Function
Finnally, we can package everything and deploy it to GCP. We will use Cloud Run to deloy our function as follows:

```shell
gcloud run deploy qa-function \
--source . \
--execution-environment gen2 \
--service-account fs-identity \
--set-env-vars INSTANCE_CONNECTION_NAME=$PROJECT_ID:$REGION:$INSTANCE_NAME
--allow-unauthenticated
```

After deployment finishes, we can test it with the following `curl`

```shell
curl -X POST -H "Content-Type: text/plain" \
-d "Tell me a joke" \
  https://my-service-abcdef-uc.a.run.app
```

## That's all folks
In a previous article, we saw how to leverage Google Cloud managed services to build a serverless large-scale data pipeline to ingest and embed documents. In this article, we implemented a scalable retrieval system on top of the previously indexed documents with **Vertex AI** and **Cloud SQL for Postgres**.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
