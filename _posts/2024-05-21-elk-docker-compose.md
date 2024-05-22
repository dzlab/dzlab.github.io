---
layout: post
comments: true
title: Setting Up Elastic-based logging stack with Docker Compose
excerpt: Learn how to quickly setup an ELK-based logging stack with Docker Compose.
categories: monitoring
tags: [docker,elastic,kibana]
toc: true
img_excerpt:
---

<img align="left" src="/assets/logos/icons8-docker.svg" width="150" />
<img align="left" src="/assets/logos/elasticsearch.svg" width="120" />
<img align="left" src="/assets/logos/kibana.svg" width="100" />
<img align="center" src="/assets/logos/elastic-beats-logo-vector.svg" width="160" />
<br/>

Having a local setup of your Elasticsearch-based logging stack helps a lot with prototyping dashboards and experimenting with logging format or index patterns, etc. This post explains how to setup locally an ELK stack to capture logs from a service running locally with Docker Compose.

First, lets define the different components of the stack:
- A Elasticsearch container that exposes port 9200
- A Kibana container that exposes its UI at 5601, with its configuration defined in `kibana.yml` (e.g. address elasticsearch server address)
- A logstash container that exposes port 9600 and configured by `logstash.conf`.
- A filebeat container configured with `filebeat.yml` to grab logs from the target service
- Zookeeper/Kafka containers to queue logs

The filebeat service will consume the logs from the target service, it will then publish them to a Kafka topic. The logstash service will consume the logs from the kafka topic and ingest them into elasticsearch. The logs can be then queried with Kibana.

The following `docker-compose.yml` file summaries the configuration of all those components:

```yaml
## docker-compose.yml ##

version: '3'

volumes:
  elastic_data: {}

services:

  elasticsearch:
    container_name: elasticsearch
    hostname: elasticsearch
    image: docker.elastic.co/elasticsearch/elasticsearch:7.9.3
    environment:
      - discovery.type=single-node
    volumes:
      - elastic_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
      - "9300:9300"

  kibana:
    container_name: kibana
    hostname: kibana
    image: docker.elastic.co/kibana/kibana:7.9.3
    volumes:
      - "./kibana.yml:/usr/share/kibana/config/kibana.yml"
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

  logstash:
    container_name: logstash
    hostname: logstash
    image: docker.elastic.co/logstash/logstash:7.9.3
    volumes:
      - ./logstash.conf:/usr/share/logstash/config/logstash.conf
    command: logstash -f /usr/share/logstash/config/logstash.conf
    ports:
      - "9600:9600"
      - "7777:7777"

  zookeeper:
    container_name: zookeeper
    hostname: zookeeper
    image: wurstmeister/zookeeper
    ports:
      - "2181:2181"

  kafka:
    container_name: kafka
    hostname: kafka
    image: wurstmeister/kafka
    ports:
      - "9092:9092"
    environment:
      KAFKA_ADVERTISED_HOST_NAME: localhost
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
    depends_on:
      - zookeeper

  filebeat:
    image: docker.elastic.co/beats/filebeat:7.9.3
    volumes:
      - ./filebeat.yml:/usr/share/filebeat/filebeat.yml
      - /path/to/your/logs:/var/log/your_service:ro
    depends_on:
      - kafka
```

Second, we need to define the configuration for the filebeat in the `filebeat.yml` file. The following is an example configuration:
- read input logs from files with pattern `/var/log/your_service/*.log`
- publish to Kafka topic `<KAFKA_TOPIC>`
- optionally define the kibana connection - [check the documentation](https://www.elastic.co/guide/en/beats/filebeat/current/setup-kibana-endpoint.html)

```yaml
## filebeat.yml ##

filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/your_service/*.log

output.kafka:
  hosts: ["kafka:9092"]
  topic: "<KAFKA_TOPIC>"
  codec.json:
    pretty: false

setup.kibana:
  host: "kibana:5601"

setup.template.settings:
  index.number_of_shards: 1
  index.codec: best_compression

setup.dashboards.enabled: true
```


Third, define the logstash configuration in `logstash.conf`. The following is an example configuration:
- Consume the logs from Kafka topic `<KAFKA_TOPIC>`
- Apply any filtering to the logs
- Ingest the logs into Elasticsearch

```ruby
## logstash.conf ##

input {
  kafka {
    bootstrap_servers => "kafka:9092"
    topics => ["<KAFKA_TOPIC>"]
    codec => "json"
    tags => ["log", "kafka_source"]
  }
}

filter {
  # Add your filters here. For example, to add a field:
  mutate {
    add_field => { "new_field" => "value" }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "<ELASTIC_INDEX>-%{+YYYY.MM.dd}"
    # user => "elastic"
    # password => "changeme"
  }
}
```

Forth, define kibana configuration in `kibana.yml`, e.g. to setup proper connection with Elasticsearch container.

```yaml
## kibana.yml ##

server.name: kibana
server.host: "0"
elasticsearch.hosts: [ "http://elasticsearch:9200" ]
```

Finally, after defining all the configuration file as well as the docker compose file we can start the monitoring stack with `docker-compose up`

```
$ docker-compose up
```

Once the containers are up and running, you can visit
- Kibana at http://localhost:5601/

To stop the monitoring stack run the following command
```
$ docker-compose down -v
```


I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
