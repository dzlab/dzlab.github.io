---
layout: post
comments: true
title: Building data pipelines with Vector by Datadog
excerpt: Learn how to build a data pipeline with Vector to ingest data from Kafka into Elasticsearch.
categories: monitoring
tags: [docker,elastic,kibana]
toc: true
img_excerpt: assets/logos/vector-by-datadog.svg
---

<img align="center" src="/assets/logos/vector-by-datadog.svg" />
<br/>



![Vector architecture]({{ "/assets/2025/02/20250215-vector.svg" | absolute_url }})


## Infra setup

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

Check all ports are open

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


ssh -vNL 5601:localhost:5601 $LDAP_USERNAME@$DEV_HOME.meraki.com


ssh -vNL 8686:localhost:8686 $LDAP_USERNAME@$DEV_HOME.meraki.com

### Kafka

connecting to kafka https://www.baeldung.com/kafka-docker-connection

List topics

```
$ docker run -it --rm --network vector_example_network confluentinc/cp-kafka /bin/kafka-topics --bootstrap-server kafka:9092 --list

logs-2025-02-15
```

Describe a topic

```
$ docker run -it --rm --network vector_example_network confluentinc/cp-kafka /bin/kafka-topics --bootstrap-server kafka:9092 --describe --topic logs-2025-02-15

Topic: logs-2025-02-15	TopicId: KS47H7xDRV2BhEI7CYyOOg	PartitionCount: 1	ReplicationFactor: 1	Configs: 
	Topic: logs-2025-02-15	Partition: 0	Leader: 1	Replicas: 1	Isr: 1	Elr: N/A	LastKnownElr: N/A
```

Manually publish messages to the topic

```
$ docker run -it --rm --network vector_example_network confluentinc/cp-kafka /bin/kafka-console-producer --bootstrap-server kafka:9092 --topic logs-2025-02-15
```

Read published messages

```
$ docker run -it --rm --network vector_example_network confluentinc/cp-kafka /bin/kafka-console-consumer --bootstrap-server kafka:9092 --topic logs-2025-02-15 --from-beginning

{"appname":"BronzeGamer","facility":"audit","hostname":"for.yun","message":"We're gonna need a bigger boat","msgid":"ID897","procid":4423,"severity":"debug","timestamp":"2025-02-15T23:50:09.677Z","version":1}
Processed a total of 1 messages
```

## Vector

![Vector pipeline]({{ "/assets/2025/02/20250215-vector-pipeline.svg" | absolute_url }})

The Kafka topics names to read events from.

Regular expression syntax is supported if the topic begins with ^.

```yaml
# vector.yaml 
api:
  enabled: true

sources:
  kafka_in:
    type: "kafka"
    bootstrap_servers: "kafka:9092"
    group_id: "logs"
    key_field: "message"
    topics: ["^logs-.+"]
    metrics:
      topic_lag_metric: true

transforms:
  json_parse:
    type: "remap"
    inputs: ["kafka_in"]
    source: |
      parsed, err = parse_json(.message)
      if err != null {
        log(err, level: "error")
      }
      . |= object(parsed) ?? {}

sinks:
  console_out:
    inputs: ["remap_syslog"]
    type: "console"
    encoding:
      codec: "json"

  elasticsearch_out:
    type: elasticsearch
    inputs: [ "remap_syslog" ]
    endpoints: ["http://elasticsearch:9200"]
    api_version: "auto"
    mode: "data_stream"
    bulk:
      action: "create"
      index: "logs-%Y-%m-%d"
    compression: "none"

  kafka_out:
    type: "kafka"
    inputs: [ "remap_syslog" ]
    bootstrap_servers: "kafka:9092"
    topic: "logs-%Y-%m-%d"
    encoding:
      codec: "json"
```

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

```
docker logs -f $(docker ps -aqf "name=vector")
```

Display topology and metrics in the console, for a local or remote Vector instance

```
$ docker exec -ti $(docker ps -aqf "name=vector") vector top
```

Output the topology as visual representation using the DOT language which can be rendered by GraphViz

```
$ docker exec -ti $(docker ps -aqf "name=vector") vector graph

digraph {
  "kafka_in" [shape="trapezium"]
  "json_parse" [shape="diamond"]
  "kafka_in" -> "json_parse"
  "elasticsearch_out" [shape="invtrapezium"]
  "json_parse" -> "elasticsearch_out"
}
```



Observe output log events from source or transform components. Logs are sampled at a specified interval

```
$ docker exec -ti $(docker ps -aqf "name=vector") vector tap

2025-02-13T23:10:13.677283Z  INFO vector::app: Log level is enabled. level="info"
[tap] Pattern '*' successfully matched.
[tap] Warning: sink outputs cannot be tapped. Output pattern '*' matches sinks ["elasticsearch_out"]
```


```
$ docker rm -f $(docker ps -aqf "name=vector")
```