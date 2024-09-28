---
layout: post
comments: true
title: From Postgres to Elasticsearch through Debezium 
excerpt: Setup CDC pipeline with Debezium to move data from Postgres to Elasticsearch
categories: debezium
tags: [docker,postgres,kafka,elasticsearch]
toc: true
img_excerpt: assets/2024/06/20240613-debezium-topology.svg
---


In a [previous article]({{ "debezium/2024/06/09/debezium-kafka/" | absolute_url }}), we saw how to set up a CDC pipeline to capture Data changes from Postgres and stream them to Kafka using Debezium. In this article, we will stream the data changes from Postgres into ElasticSearch using Debezium, Kafka.


## Toplogy

![Debezium toplogy]({{ "/assets/2024/06/20240613-debezium-topology.svg" | absolute_url }})

we will use a separate container for each service and don’t use persistent volume. ZooKeeper and Kafka would typically store their data locally inside the containers, which would require you to mount directories on the host machine as volumes. So in this tutorial, all persisted data is lost when a container is stopped

You need to install the Elasticsearch sink connector separately or use the Kafka Connect images from Confluent and install Debezium into those https://www.confluent.io/hub/debezium/debezium-connector-postgresql


`Dockerfile.connect-jdbc-es`

```Dockerfile
ARG DEBEZIUM_VERSION
FROM debezium/connect:${DEBEZIUM_VERSION}
ENV KAFKA_CONNECT_JDBC_DIR=$KAFKA_CONNECT_PLUGINS_DIR/kafka-connect-jdbc \
    KAFKA_CONNECT_ES_DIR=$KAFKA_CONNECT_PLUGINS_DIR/kafka-connect-elasticsearch

ARG POSTGRES_VERSION=42.5.1
ARG KAFKA_JDBC_VERSION=5.3.2
ARG KAFKA_ELASTICSEARCH_VERSION=5.3.2

# Deploy PostgreSQL JDBC Driver
RUN cd /kafka/libs && curl -sO https://jdbc.postgresql.org/download/postgresql-$POSTGRES_VERSION.jar

# Deploy Kafka Connect JDBC
RUN mkdir $KAFKA_CONNECT_JDBC_DIR && cd $KAFKA_CONNECT_JDBC_DIR &&\
	curl -sO https://packages.confluent.io/maven/io/confluent/kafka-connect-jdbc/$KAFKA_JDBC_VERSION/kafka-connect-jdbc-$KAFKA_JDBC_VERSION.jar

# Deploy Confluent Elasticsearch sink connector
RUN mkdir $KAFKA_CONNECT_ES_DIR && cd $KAFKA_CONNECT_ES_DIR &&\
        curl -sO https://packages.confluent.io/maven/io/confluent/kafka-connect-elasticsearch/$KAFKA_ELASTICSEARCH_VERSION/kafka-connect-elasticsearch-$KAFKA_ELASTICSEARCH_VERSION.jar && \
        curl -sO https://repo1.maven.org/maven2/io/searchbox/jest/6.3.1/jest-6.3.1.jar && \
        curl -sO https://repo1.maven.org/maven2/org/apache/httpcomponents/httpcore-nio/4.4.4/httpcore-nio-4.4.4.jar && \
        curl -sO https://repo1.maven.org/maven2/org/apache/httpcomponents/httpclient/4.5.1/httpclient-4.5.1.jar && \
        curl -sO https://repo1.maven.org/maven2/org/apache/httpcomponents/httpasyncclient/4.1.1/httpasyncclient-4.1.1.jar && \
        curl -sO https://repo1.maven.org/maven2/org/apache/httpcomponents/httpcore/4.4.4/httpcore-4.4.4.jar && \
        curl -sO https://repo1.maven.org/maven2/commons-logging/commons-logging/1.2/commons-logging-1.2.jar && \
        curl -sO https://repo1.maven.org/maven2/commons-codec/commons-codec/1.9/commons-codec-1.9.jar && \
        curl -sO https://repo1.maven.org/maven2/org/apache/httpcomponents/httpcore/4.4.4/httpcore-4.4.4.jar && \
        curl -sO https://repo1.maven.org/maven2/io/searchbox/jest-common/6.3.1/jest-common-6.3.1.jar && \
        curl -sO https://repo1.maven.org/maven2/com/google/code/gson/gson/2.8.6/gson-2.8.6.jar && \
        curl -sO https://repo1.maven.org/maven2/com/google/guava/guava/31.0.1-jre/guava-31.0.1-jre.jar
```

```shell
export DEBEZIUM_VERSION=2.1
docker build -t debezium/connect-jdbc-es:${DEBEZIUM_VERSION} --build-arg DEBEZIUM_VERSION=${DEBEZIUM_VERSION} -f Dockerfile.connect-jdbc-es .
```

```
[+] Building 6.4s (8/8) FINISHED                                                                                                                             docker:default
 => [internal] load build definition from Dockerfile.connect-jdbc-es                                                                                                   0.0s
 => => transferring dockerfile: 2.26kB                                                                                                                                 0.0s
 => [internal] load metadata for docker.io/debezium/connect:2.1                                                                                                        0.0s
 => [internal] load .dockerignore                                                                                                                                      0.0s
 => => transferring context: 2B                                                                                                                                        0.0s
 => [1/4] FROM docker.io/debezium/connect:2.1                                                                                                                          0.2s
 => [2/4] RUN cd /kafka/libs && curl -sO https://jdbc.postgresql.org/download/postgresql-42.5.1.jar                                                                    1.6s
 => [3/4] RUN mkdir /kafka/connect/kafka-connect-jdbc && cd /kafka/connect/kafka-connect-jdbc && curl -sO https://packages.confluent.io/maven/io/confluent/kafka-conn  0.6s
 => [4/4] RUN mkdir /kafka/connect/kafka-connect-elasticsearch && cd /kafka/connect/kafka-connect-elasticsearch &&        curl -sO https://packages.confluent.io/mave  3.8s
 => exporting to image                                                                                                                                                 0.1s
 => => exporting layers                                                                                                                                                0.0s
 => => writing image sha256:90d40c1d011179c31f33a52122f661a08e29ed695eba67503fa0035120678f2f                                                                           0.0s
 => => naming to docker.io/debezium/connect-jdbc-es:2.1                                                                                                                0.0s
```

### Setup With Docker

```shell
docker run -d --rm --name zookeeper -p 2181:2181 -p 2888:2888 -p 3888:3888 debezium/zookeeper:${DEBEZIUM_VERSION}

docker run -d --rm --name kafka -p 9092:9092 --link zookeeper -e ZOOKEEPER_CONNECT=zookeeper:2181 debezium/kafka:${DEBEZIUM_VERSION}

docker run -d --rm --name postgres -p 6432:5432 -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres debezium/postgres

docker run -d --rm --name elastic -p 9200:9200 -e http.host=0.0.0.0 -e transport.host=127.0.0.1 -e xpack.security.enabled=false -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" docker.elastic.co/elasticsearch/elasticsearch:7.3.0

docker run -d --rm --name connect -p 8083:8083 -p 5005:5005 --link kafka --link postgres --link elastic -e BOOTSTRAP_SERVERS=kafka:9092 -e GROUP_ID=1 -e CONFIG_STORAGE_TOPIC=my_connect_configs -e OFFSET_STORAGE_TOPIC=my_connect_offsets -e STATUS_STORAGE_TOPIC=my_connect_statuses debezium/connect-jdbc-es:${DEBEZIUM_VERSION}
```

### Setup with Docker Compose

`docker-compose.yaml`

```yaml
version: '2'
services:
  zookeeper:
    image: debezium/zookeeper:${DEBEZIUM_VERSION}
    ports:
     - 2181:2181
     - 2888:2888
     - 3888:3888
  kafka:
    image: debezium/kafka
    ports:
     - 9092:9092
    links:
     - zookeeper
    environment:
     - ZOOKEEPER_CONNECT=zookeeper:2181
  postgres:
    image: debezium/postgres
    ports:
     - 5432:5432
    environment:
     - POSTGRES_USER=postgres
     - POSTGRES_PASSWORD=postgres
  elastic:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.3.0
    ports:
     - "9200:9200"
    environment:
     - http.host=0.0.0.0
     - transport.host=127.0.0.1
     - xpack.security.enabled=false
     - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
  connect:
    image: debezium/connect-jdbc-es:${DEBEZIUM_VERSION}
    ports:
     - 8083:8083
     - 5005:5005
    links:
     - kafka
     - postgres
     - elastic
    environment:
     - BOOTSTRAP_SERVERS=kafka:9092
     - GROUP_ID=1
     - CONFIG_STORAGE_TOPIC=my_connect_configs
     - OFFSET_STORAGE_TOPIC=my_connect_offsets
     - STATUS_STORAGE_TOPIC=my_connect_statuses
```

Start the topology as defined in https://debezium.io/documentation/reference/stable/tutorial.html

```shell
export DEBEZIUM_VERSION=2.1
docker-compose -f docker-compose.yaml up
```

### Check everything is running

```shell
$ docker ps | grep debezium
2792950fced9   debezium/connect-jdbc-es:2.1                                                                                   "/docker-entrypoint.…"   35 seconds ago       Up 33 seconds           127.0.0.1:5005->5005/tcp, 127.0.0.1:8083->8083/tcp, 9092/tcp                   connect
ddb60a7cc254   debezium/postgres                                                                                              "docker-entrypoint.s…"   About a minute ago   Up About a minute       127.0.0.1:6432->5432/tcp                                                       postgres
0ccb46011ffa   debezium/kafka:2.1                                                                                             "/docker-entrypoint.…"   About a minute ago   Up About a minute       127.0.0.1:9092->9092/tcp                                                       kafka
cca024019c84   debezium/zookeeper:2.1                                                                                         "/docker-entrypoint.…"   About a minute ago   Up About a minute       127.0.0.1:2181->2181/tcp, 127.0.0.1:2888->2888/tcp, 127.0.0.1:3888->3888/tcp   zookeeper
964282a73ee3   debezium/connect:2.1                                                                                           "/docker-entrypoint.…"   4 days ago           Up 4 days               8083/tcp, 9092/tcp                                                             agitated_mccarthy
```


## Register Connectors with Debezium

```shell
$ curl -H "Accept:application/json" localhost:8083/
{"version":"3.3.1","commit":"e23c59d00e687ff5","kafka_cluster_id":"UBy0Y35cSfOg-Ltt4kBK3g"}
```

```shell
$ curl -H "Accept:application/json" localhost:8083/connectors/
[]
```

### Register Postgres source

`pg-source.json`

```json
{
    "name": "pg-source",
    "config": {
        "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
        "tasks.max": "1",
        "database.hostname": "postgres",
        "database.port": "5432",
        "database.user": "postgres",
        "database.password": "postgres",
        "database.dbname" : "postgres",
        "topic.prefix": "dbserver1",
        "schema.include.list": "inventory",
        "schema.history.internal.kafka.bootstrap.servers": "kafka:9092",
        "schema.history.internal.kafka.topic": "schema-changes.inventory",
        "transforms": "route",
        "transforms.route.type": "org.apache.kafka.connect.transforms.RegexRouter",
        "transforms.route.regex": "([^.]+)\\.([^.]+)\\.([^.]+)",
        "transforms.route.replacement": "$3"
    }
}
```

Start Postgres connector

```shell
$ curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @pg-source.json

{"name":"pg-source","config":{"connector.class":"io.debezium.connector.postgresql.PostgresConnector","tasks.max":"1","database.hostname":"postgres","database.port":"5432","database.user":"postgres","database.password":"postgres","database.dbname":"postgres","topic.prefix":"dbserver1","schema.include.list":"inventory","schema.history.internal.kafka.bootstrap.servers":"kafka:9092","schema.history.internal.kafka.topic":"schema-changes.inventory","transforms":"route","transforms.route.type":"org.apache.kafka.connect.transforms.RegexRouter","transforms.route.regex":"([^.]+)\\.([^.]+)\\.([^.]+)","transforms.route.replacement":"$3","name":"pg-source"},"tasks":[],"type":"source"}
```

Check that the connector is created:


```shell
$ curl -H "Accept:application/json" localhost:8083/connectors/
["pg-source"]
```

Check that the connector is running:

```shell
$ curl localhost:8083/connectors/pg-source/status
{"name":"pg-source","connector":{"state":"RUNNING","worker_id":"172.17.0.19:8083"},"tasks":[{"id":0,"state":"RUNNING","worker_id":"172.17.0.19:8083"}],"type":"source"}
```

The first time it connects to a PostgreSQL server, Debezium takes a [consistent snapshot](https://debezium.io/documentation/reference/1.6/connectors/postgresql.html#postgresql-snapshots) of the tables selected for replication, so you should see that the pre-existing records in the replicated table are initially pushed into your Kafka topic:

### Register Elasticsearch sink

`es-sink.json`

```json
{
    "name": "elastic-sink",
    "config": {
        "connector.class": "io.confluent.connect.elasticsearch.ElasticsearchSinkConnector",
        "tasks.max": "1",
        "topics": "customers",
        "connection.url": "http://elastic:9200",
        "transforms": "unwrap,key",
        "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
        "transforms.unwrap.drop.tombstones": "false",
        "transforms.key.type": "org.apache.kafka.connect.transforms.ExtractField$Key",
        "transforms.key.field": "id",
        "key.ignore": "false",
        "type.name": "customer",
        "behavior.on.null.values": "delete"
    }
}
```

```shell
$ curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @es-sink.json

{"name":"elastic-sink","config":{"connector.class":"io.confluent.connect.elasticsearch.ElasticsearchSinkConnector","tasks.max":"1","topics":"customers","connection.url":"http://elastic:9200","transforms":"unwrap,key","transforms.unwrap.type":"io.debezium.transforms.ExtractNewRecordState","transforms.unwrap.drop.tombstones":"false","transforms.key.type":"org.apache.kafka.connect.transforms.ExtractField$Key","transforms.key.field":"id","key.ignore":"false","type.name":"customer","behavior.on.null.values":"delete","name":"elastic-sink"},"tasks":[],"type":"sink"}
```

```shell
$ curl -H "Accept:application/json" localhost:8083/connectors/
["elastic-sink","pg-source"]
```

```shell
$ curl localhost:8083/connectors/elastic-sink/status

{"name":"elastic-sink","connector":{"state":"RUNNING","worker_id":"172.17.0.19:8083"},"tasks":[{"id":0,"state":"RUNNING","worker_id":"172.17.0.19:8083"}],"type":"sink"}
```

## Populate Postgres with Data

Modify records in the database via Postgres client
```shell
$ docker exec -it --env PGOPTIONS="--search_path=inventory" postgres /bin/bash -c 'psql -U $POSTGRES_USER postgres'
postgres=# 
```

https://github.com/debezium/container-images/blob/main/examples/postgres/3.0/inventory.sql

```sql
CREATE SCHEMA inventory;
SET search_path TO inventory;
-- Create some customers ...
CREATE TABLE customers (
  id SERIAL NOT NULL PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE
);
ALTER SEQUENCE customers_id_seq RESTART WITH 1001;
ALTER TABLE customers REPLICA IDENTITY FULL;

INSERT INTO customers
VALUES (default,'Sally','Thomas','sally.thomas@acme.com'),
       (default,'George','Bailey','gbailey@foobar.com'),
       (default,'Edward','Walker','ed@walker.com'),
       (default,'Anne','Kretchmar','annek@noanswer.org');
```


## Elasticsearch

```shell
curl 'http://localhost:9200/customers/_search?pretty'
```

```json
{
  "took" : 836,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 4,
      "relation" : "eq"
    },
    "max_score" : 1.0,
    "hits" : [
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1003",
        "_score" : 1.0,
        "_source" : {
          "id" : 1003,
          "first_name" : "Edward",
          "last_name" : "Walker",
          "email" : "ed@walker.com"
        }
      },
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1004",
        "_score" : 1.0,
        "_source" : {
          "id" : 1004,
          "first_name" : "Anne",
          "last_name" : "Kretchmar",
          "email" : "annek@noanswer.org"
        }
      },
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1002",
        "_score" : 1.0,
        "_source" : {
          "id" : 1002,
          "first_name" : "George",
          "last_name" : "Bailey",
          "email" : "gbailey@foobar.com"
        }
      },
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1001",
        "_score" : 1.0,
        "_source" : {
          "id" : 1001,
          "first_name" : "Sally",
          "last_name" : "Thomas",
          "email" : "sally.thomas@acme.com"
        }
      }
    ]
  }
}
```



## Shut down the cluster

```shell
docker stop connect
docker stop kafka
docker stop zookeeper
docker stop elastic
docker stop postgres
```

```shell
# Shut down the cluster
$ docker-compose -f docker-compose.yaml down
```

## That's all folks
In this article, we saw how to configure Debezium to stream WAL transactions from Postgres to Elasticsearch.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).