---
layout: post
comments: true
title: Building data pipelines with Vector by Datadog
excerpt: Learn how to build a data pipeline with Vector to ingest data into Elasticsearch.
categories: monitoring
tags: [docker,elastic,kibana]
toc: true
img_excerpt: assets/logos/vector-by-datadog.svg
---

<img align="center" src="/assets/logos/vector-by-datadog.svg" />
<br/>


[Vector](https://vector.dev/) is an open-source log aggregator developed by Datadog. Vector is a lightweight, exceptionally fast, and memory efficiency alternative to [Logstash](https://www.elastic.co/logstash). Vector makes it easy to build observability pipelines by seamlessly capturing logs from many sources, applying transformations, and routing to one of the many predefined sinks.

![Vector architecture]({{ "/assets/2025/02/20250215-vector.svg" | absolute_url }})

In this article, we will explore how to leverage Vector to collect syslog messages, transform them into JSON events, then write to a Kafka topic as well as an Elasticsearch Index.


## Infrastructure setup

First, let's setup the infrastructure using Docker. The following Docker Compose file defines the setup with the following components:

* **ZooKeeper** a coordination service for distributed systems, used by Kafka. It exposes port 2181 (mapped to host port 22181).
* **Kafka** a distributed event streaming platform, exposes port 29092 (for host access)
* **Elasticsearch**: a Search and analytics engine, available on port 9200
* **Kibana** a Data visualization dashboard for Elasticsearch, available on port 5601

Additionally, all services are connected through a custom Docker network called.

```yaml
# docker-compose.yaml
version: '3.8'

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.4
    container_name: zookeeper
    networks:
      - vecnet
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - 22181:2181

  kafka:
    image: confluentinc/cp-kafka:7.4.4
    container_name: kafka
    networks:
      - vecnet
    depends_on:
      - zookeeper
    ports:
      - 29092:29092
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:29092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.16.3
    container_name: elasticsearch
    networks:
      - vecnet
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
  kibana:
    image: docker.elastic.co/kibana/kibana:7.16.3
    container_name: kibana
    networks:
      - vecnet
    environment:
      - ELASTICSEARCH_URL=http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

networks:
  vecnet:
    name: vector_example_network
```

We can start the infrastructure as follows:

```
$ docker-compose up -d

Creating network "vector_example_network" with the default driver
Creating zookeeper     ... done
Creating elasticsearch ... done
Creating kibana        ... done
Creating kafka         ... done
```

Check all services are running

```
$ docker-compose ps

    Name                   Command               State                               Ports                             
-----------------------------------------------------------------------------------------------------------------------
elasticsearch   /bin/tini -- /usr/local/bi ...   Up      0.0.0.0:9200->9200/tcp,:::9200->9200/tcp, 9300/tcp            
kafka           /etc/confluent/docker/run        Up      0.0.0.0:29092->29092/tcp,:::29092->29092/tcp, 9092/tcp        
kibana          /bin/tini -- /usr/local/bi ...   Up      0.0.0.0:5601->5601/tcp,:::5601->5601/tcp                      
zookeeper       /etc/confluent/docker/run        Up      0.0.0.0:22181->2181/tcp,:::22181->2181/tcp, 2888/tcp, 3888/tcp
```

Another check to perform before moving further, is to verify that all exposed ports are open

```
$ nc -zv localhost 22181
Connection to localhost 22181 port [tcp/*] succeeded!

$ nc -zv localhost 29092
Connection to localhost 29092 port [tcp/*] succeeded!

$ nc -zv localhost 9200
Connection to localhost 9200 port [tcp/*] succeeded!

$ nc -zv localhost 5601
Connection to localhost 5601 port [tcp/*] succeeded!
```

## Vector
In this section, we will build the data processing pipeline for our log data, specifically using Vector, which is a high-performance observability data pipeline tool. Our pipeline will generate few samples of syslog data, apply some transformations, then send the processed data to selected destinations.

![Vector pipeline]({{ "/assets/2025/02/20250215-vector-pipeline.svg" | absolute_url }})

The structure of a our Vector pipeline as defined in the below YAML file, is as follows:

- **Sources**: defines the input data origin. In our case, we will simply generate sample syslog data.
- **Transforms**: defines a step called `remap_syslog` to parse the syslog-formatted messages into structured data, then extract few fields like timestamp, severity, facility, etc.
- **Sinks**: defines the output of the pipeline; we use Console Output to monitor in real-time the output of the pipeline. We also forward the data for storage into Elasticsearch and Kafka.


```yaml
# vector.yaml 
api:
  enabled: true

sources:
  generate_syslog:
    type: "demo_logs"
    format: "syslog"
    count: 50

transforms:
  remap_syslog:
    inputs: [ "generate_syslog"]
    type: "remap"
    source: |
      parsed = parse_syslog!(.message)
      . = object(parsed)

sinks:
  console_out:
    inputs: ["remap_syslog"]
    type: "console"
    encoding:
      codec: "json"

  elasticsearch_out:
    type: "elasticsearch"
    inputs: ["remap_syslog"]
    healthcheck: false
    endpoints: ["http://elasticsearch:9200"]

  kafka_out:
    type: "kafka"
    inputs: [ "remap_syslog" ]
    bootstrap_servers: "kafka:9092"
    topic: "logs-%Y-%m-%d"
    encoding:
      codec: "json"
```

Now we can start the Vector service and pass in the YAML file containing the pipeline definition

```
docker run \
  -d \
  -v $PWD/vector.yaml:/etc/vector/vector.yaml:ro \
  -p 8686:8686 \
  --name vector \
  --network vector_example_network \
  timberio/vector:nightly-debian
```

> Note: use the `--verbose` to get debug level logging

Validate the target config, then exit

```
$ docker exec -ti $(docker ps -aqf "name=vector") vector validate

√ Loaded ["/etc/vector/vector.yaml"]
√ Component configuration
√ Health check "elasticsearch_out"
------------------------------------
                           Validated
```

Check the logs from the container running Vector to make sure everything is running correctly:

```
docker logs -f $(docker ps -aqf "name=vector")
```

Display Vector's metrics in the console

```
$ docker exec -ti $(docker ps -aqf "name=vector") vector top
```

Output the topology as visual representation using the DOT language which can be rendered by GraphViz

```
$ docker exec -ti $(docker ps -aqf "name=vector") vector graph

digraph {
  "generate_syslog" [shape="trapezium"]
  "remap_syslog" [shape="diamond"]
  "generate_syslog" -> "remap_syslog"
  "elasticsearch_out" [shape="invtrapezium"]
  "remap_syslog" -> "elasticsearch_out"
}
```

Also, we can observe output log events from the source or transform components:

```
$ docker exec -ti $(docker ps -aqf "name=vector") vector tap

2025-02-13T23:10:13.677283Z  INFO vector::app: Log level is enabled. level="info"
[tap] Pattern '*' successfully matched.
[tap] Warning: sink outputs cannot be tapped. Output pattern '*' matches sinks ["elasticsearch_out"]

{"appname":"BronzeGamer","facility":"local4","hostname":"names.rsvp","message":"#hugops to everyone who has to deal with this","msgid":"ID347","procid":6651,"severity":"emerg","timestamp":"2025-02-28T00:08:10.006Z","version":2}
```

## Kafka setup
Our Vector pipeline will forward message to a Kafka topic, we can list topics to verify that our topic for receiving events:

```
$ docker run -it --rm --network vector_example_network confluentinc/cp-kafka /bin/kafka-topics --bootstrap-server kafka:9092 --list

logs-2025-02-15
```

We can also list more information about the topic created by Vector:

```
$ docker run -it --rm --network vector_example_network confluentinc/cp-kafka /bin/kafka-topics --bootstrap-server kafka:9092 --describe --topic logs-2025-02-15

Topic: logs-2025-02-15	TopicId: KS47H7xDRV2BhEI7CYyOOg	PartitionCount: 1	ReplicationFactor: 1	Configs: 
	Topic: logs-2025-02-15	Partition: 0	Leader: 1	Replicas: 1	Isr: 1	Elr: N/A	LastKnownElr: N/A
```

Optionally publish messages to the topic manually for testing:

```
$ docker run -it --rm --network vector_example_network confluentinc/cp-kafka /bin/kafka-console-producer --bootstrap-server kafka:9092 --topic logs-2025-02-15
```

Read the published messages as they are pushed to Kafka

```
$ docker run -it --rm --network vector_example_network confluentinc/cp-kafka /bin/kafka-console-consumer --bootstrap-server kafka:9092 --topic logs-2025-02-15 --from-beginning

{"appname":"BronzeGamer","facility":"audit","hostname":"for.yun","message":"We're gonna need a bigger boat","msgid":"ID897","procid":4423,"severity":"debug","timestamp":"2025-02-15T23:50:09.677Z","version":1}
Processed a total of 1 messages
```

## Elasticsearch

Elasticsearch is another destination for the logs shipped by Vector. We can list the indices and check that we have one created by Vector:

```
$ curl -s http://localhost:9200/_aliases | jq

{
  ...
  "vector-2025.02.28": {
    "aliases": {}
  },
  ...
}
```

We can check the structure of the documents that will be sent by Vector

```
$ curl -s http://localhost:9200/vector-2025.02.28 | jq

{
  "vector-2025.02.28": {
    "aliases": {},
    "mappings": {
      "properties": {
        "appname": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "facility": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "hostname": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "message": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "msgid": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "procid": {
          "type": "long"
        },
        "severity": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "timestamp": {
          "type": "date"
        },
        "version": {
          "type": "long"
        }
      }
    },
    "settings": {
      "index": {
        "routing": {
          "allocation": {
            "include": {
              "_tier_preference": "data_content"
            }
          }
        },
        "number_of_shards": "1",
        "provided_name": "vector-2025.02.28",
        "creation_date": "1740701263010",
        "number_of_replicas": "1",
        "uuid": "GE9reUyzTSyS0W-og3YQ6g",
        "version": {
          "created": "7160399"
        }
      }
    }
  }
}
```

We can view the documents inserted in this index by Vector

```
$ curl -s 'http://localhost:9200/vector-2025.02.28/_search?pretty=true&size=1'

{
  "took" : 1,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 50,
      "relation" : "eq"
    },
    "max_score" : 1.0,
    "hits" : [
      {
        "_index" : "vector-2025.02.28",
        "_type" : "_doc",
        "_id" : "Yo_hSZUBbMT2FeGGgyTf",
        "_score" : 1.0,
        "_source" : {
          "appname" : "BryanHorsey",
          "facility" : "uucp",
          "hostname" : "random.helsinki",
          "message" : "Pretty pretty pretty good",
          "msgid" : "ID4",
          "procid" : 4488,
          "severity" : "notice",
          "timestamp" : "2025-02-28T00:07:50.006Z",
          "version" : 2
        }
      }
    ]
  }
}
```

## Wrapping up
Stop the Vector container

```
$ docker rm -f $(docker ps -aqf "name=vector")
```

And tear down the infrastucture previously setup with Docker Compose:

```
$ docker-compose down

Stopping kafka         ... done
Stopping kibana        ... done
Stopping zookeeper     ... done
Stopping elasticsearch ... done
Removing kafka         ... done
Removing kibana        ... done
Removing zookeeper     ... done
Removing elasticsearch ... done
Removing network vector_example_network
```

## That's all folks

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
