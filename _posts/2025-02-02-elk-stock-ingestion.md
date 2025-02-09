---
layout: post
comments: true
title: Ingesting Stocks historical data into Elasticsearch
excerpt: Learn how to setup ELK with docker-compose and ingest stocks data into Elasticsearch.
categories: monitoring
tags: [docker,elastic,kibana]
toc: true
img_excerpt:
---

<img align="left" src="/assets/logos/icons8-docker.svg" width="150" />
<img align="left" src="/assets/logos/elasticsearch.svg" width="120" />
<img align="center" src="/assets/logos/kibana.svg" width="100" />
<br/>

For those seeking to gain a deeper understanding of market trends, economic fluctuations, and consumer behavior, historical stock data is a treasure trove of insights waiting to be unearthed.

In this blog post, we'll explore how to ingest historical stock data into Elasticsearch. From data preparation to indexing, we'll delve into the steps required to harness the power of historical data and supercharge your analytics engine with actionable insights.

## Infrastructure setup

In this section, we'll dive into the different components of our architecture (Elasticsearch, Kibana, and our custom ingestion application), and how to brings them together in containerized environment using Docker-Compose.

The directory structure of the application and the different files needed for the setup is as follows:

```
├── docker-compose.yml
└── ingestr
    ├── Dockerfile
    ├── main.py
    ├── mappings.json
    └── requirements.txt
```

The following `docker-compose.yml` configuration file defines the relationships between the different services and networks:

* Run a single-node Elasticsearch cluster reachable on port 9200 and with security enabled
* Deploy Kibana alongside Elasticsearch for seamless data visualization and exploration. The server is availabe on port 5601, and will connect to Elasticsearch at http://elasticsearch:9200
* Build and deploy our custom ingesting application, which will be responsible for pushing historical stock data into Elasticsearch. This containerized application will be built from the `Dockerfile` located under the `./ingestr` directory.
* Setup networking using the `bridge` driver to connect all three services, allowing them to communicate seamlessly with each other.

```yaml
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.16.3
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=true
      - ELASTIC_PASSWORD=yourpassword
    ports:
      - "9200:9200"
    networks:
      - elastic

  kibana:
    image: docker.elastic.co/kibana/kibana:7.16.3
    container_name: kibana
    environment:
      - ELASTICSEARCH_URL=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=yourpassword
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
    networks:
      - elastic

  ingestr:
    container_name: ingestr
    environment:
      - ELASTICSEARCH_URL=http://elasticsearch:9200
    build:
      context: ./ingestr
      dockerfile: Dockerfile
    depends_on:
      - elasticsearch
    networks:
      - elastic

networks:
  elastic:
    driver: bridge
```

## Ingestion application

### Containerization

The following `Dockerfile` is used to build a container for running the ingestion application written in Python. Here's a step-by-step breakdown of what it does:

* Installs pip and sets up a new user named "worker" with a home directory.
* Sets up the `PATH` environment variable for the new user.
* Copies and installs the required packages listed in `requirements.txt`.
* Copies the application code into the container.
* Sets the default command to run the `main.py` file.

When you build this Dockerfile, it will create a container that can be started with the command `docker run -it <image_name>`, where `<image_name>` is the name given to the resulting image when building the Dockerfile.


```Dockerfile
FROM python

RUN pip install --upgrade pip

RUN useradd -ms /bin/bash worker
USER worker
WORKDIR /home/worker

ENV PATH="/home/worker/.local/bin:${PATH}"

COPY --chown=worker:worker requirements.txt requirements.txt
RUN pip install --user -r requirements.txt

COPY --chown=worker:worker . .


CMD ["python", "main.py"]
```

The depdencies of the application are defined in the `requirements.txt` file:

```
requests_html
lxml_html_clean
yahoo_fin
elasticsearch[async]
```

### Application logic

The following Python code snippet from the `main.py` file implements the ingestion application that feeds historical stock data from Yahoo Finance into Elasticsearch. The code is organized around the following business functionalities:

* Yahoo Finance Data Retrieval: historical data are retrieved from Yahoo Finance using the `yahoo_fin` library. We fetch the list of tickers in the Dow Jones Industrial Average (Dow 30) and then iterates through each ticker to collect its corresponding historical data.

* Interactions with Elasticsearch: Elasticsearch index creation using mapping from the `mappings.json` that defines the structure of the documents that will be indexed. Also, we define the ingestion method that uses Elasic asyncio python library to store stocks data.

* Asyncio Integration: the application uses `asyncio` library to handle the different tasks concurrently, such as connecting to Elasticsearch, loading mappings, creating an index, and ingesting data.


```python
import asyncio
from elasticsearch import AsyncElasticsearch
import json
import yahoo_fin.stock_info as si
import os

#-------------------------------------------
# Yahoo Finance Data
#-------------------------------------------
def get_historical_data():
  dow_list = si.tickers_dow()
  print(f"Tickers in Dow Jones ({len(dow_list)}): {dow_list}")
  dow_historical = []
  for ticker in dow_list:
    dow_historical.append(si.get_data(ticker))
  return dow_historical

#-------------------------------------------
# Elastic Functions
#-------------------------------------------
async def create_index(es, name, mappings):
  if not await es.indices.exists(index=name):
    await es.indices.create(index=name, mappings=mappings)
    print(f"Index created: {name}")
  else:
    print(f"Index exists: {name}")


async def ingest_data(es, index_name):
  parsed_data = get_historical_data()
  await es.index(index=index_name, document=parsed_data)

#-------------------------------------------
# Main Function
#-------------------------------------------
async def main():
  # Connect to Elasticsearch
  es_url = os.environ.get('ELASTICSEARCH_URL')
  es = AsyncElasticsearch(hosts=[es_url])

  # Load mappings
  with open('mappings.json', 'r') as f:
    mappings = '\n'.join(f.readlines())
    mappings = json.loads(mappings)
  
  # Create index
  await create_index(es, "stocks-index", mappings)
  # Ingest data
  await ingest_data_callback(es, "stocks-index")

#-------------------------------------------
# Run Main Function
#-------------------------------------------
try:
  asyncio.run(main())
except KeyboardInterrupt:
  print('keyboard interrupt, bye')
  pass
```

### Indexing stocks data

The `mappings.json` JSON file defines the mapping definition for the stocks index. It specifies the structure of the documents with six fields: ticker, date, open, close, adjclose, high, low, and volume.

```json
{
  "properties": {
    "ticker": {
        "type": "keyword"
    },
    "date": {
        "type": "date"
    },
    "open": {
        "type": "float"
    },
    "close": {
        "type": "float"
    },
    "adjclose": {
        "type": "float"
    },
    "high": {
        "type": "float"
    },
    "low": {
        "type": "float"
    },
    "volume": {
        "type": "integer"
    }
  }
}
```

## That's all folks

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
