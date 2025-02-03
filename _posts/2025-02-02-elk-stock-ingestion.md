---
layout: post
comments: true
title: Ingesting Stocks historical data into Elasticsearch
excerpt: Learn how to quickly setup an ELK-based stack to ingest stocks data.
categories: monitoring
tags: [docker,elastic,kibana]
toc: true
img_excerpt:
---

<img align="left" src="/assets/logos/icons8-docker.svg" width="150" />
<img align="left" src="/assets/logos/elasticsearch.svg" width="120" />
<img align="center" src="/assets/logos/kibana.svg" width="100" />
<br/>

```
├── docker-compose.yml
└── ingestr
    ├── Dockerfile
    ├── main.py
    ├── mappings.json
    └── requirements.txt
```

`docker-compose.yml`

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

`Dockerfile`

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

`requirements.txt`

```
requests_html
lxml_html_clean
yahoo_fin
elasticsearch[async]
```

`main.py`

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

`mappings.json`

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

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
