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


After deployment finishes and the service becomes available, we can test it with the following `curl`
```shell
curl -X POST -H "Content-Type: text/plain" -d "Tell me a joke" https://my-service-abcdef-uc.a.run.app
```

## That's all folks
In this article we saw how easy it is to use Google Cloud Run to package LLM applications, and leaverage Cloud Storage to store the weights once and for all.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
