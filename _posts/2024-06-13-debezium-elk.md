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

The below diagram highlights the different components of our cluster:
- Postgres - a Relational Database for storing the data and representing the changes source
- [Apache Kafka](https://kafka.apache.org/) - used to create a messaging topic which will store the CDC data coming from the database.
- [Apache Zookeeper](https://zookeeper.apache.org/) - a centralized service that provides distributed synchronization. It is used by Kafka to store configuration management.
- [Debezium](https://github.com/debezium/debezium) — a CDC tool based on [Kafka Connect](https://www.confluent.io/product/connectors/) to stream WAL data from source system to Kafka. It will be run with the following connectors:
  - Debezium Source for Postgres: this connector is used to read transactions log from Postgres
  - Debezium Sink for Elasticsearch: this connector is used to write documents into Elasticsearch

We will use a separate container for each service without use of persistent volumes. Data will be stored locally inside the containers, and will be lost when the container is stopped. You can mount directories on the host machine as volumes in case you want to persist data between restarts.

![Debezium toplogy]({{ "/assets/2024/06/20240613-debezium-topology.svg" | absolute_url }})

### Build Docker image for Debezium

By default, Debezium Docker image does not ship with the Elasticsearch sink connector so we need to build an image ourselves by starting from `debezium/connect` Docker image and then installing on it the Elasticsearch sink connector.
Create a `Dockerfile.connect-jdbc-es` Dockerfile with the following instructions:

```Dockerfile
ARG DEBEZIUM_VERSION
FROM debezium/connect:${DEBEZIUM_VERSION}
ENV KAFKA_CONNECT_ES_DIR=$KAFKA_CONNECT_PLUGINS_DIR/kafka-connect-elasticsearch

ARG KAFKA_ELASTICSEARCH_VERSION=5.3.2

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

Build the Docker image

```shell
export DEBEZIUM_VERSION=2.1
docker build -t debezium/connect-jdbc-es:${DEBEZIUM_VERSION} --build-arg DEBEZIUM_VERSION=${DEBEZIUM_VERSION} -f Dockerfile.connect-jdbc-es .
```

The build output should look something like this:

```
[+] Building 6.4s (8/8) FINISHED                                                                                                                             docker:default
 => [internal] load build definition from Dockerfile.connect-jdbc-es                                                                                                   0.0s
 => => transferring dockerfile: 2.26kB                                                                                                                                 0.0s
 => [internal] load metadata for docker.io/debezium/connect:2.1                                                                                                        0.0s
 => [internal] load .dockerignore                                                                                                                                      0.0s
 => => transferring context: 2B                                                                                                                                        0.0s
 => [1/2] FROM docker.io/debezium/connect:2.1                                                                                                                          0.2s
 => [2/2] RUN mkdir /kafka/connect/kafka-connect-elasticsearch && cd /kafka/connect/kafka-connect-elasticsearch &&        curl -sO https://packages.confluent.io/mave  3.8s
 => exporting to image                                                                                                                                                 0.1s
 => => exporting layers                                                                                                                                                0.0s
 => => writing image sha256:90d40c1d011179c31f33a52122f661a08e29ed695eba67503fa0035120678f2f                                                                           0.0s
 => => naming to docker.io/debezium/connect-jdbc-es:2.1                                                                                                                0.0s
```

### Setup With Docker

Now, we start each service of the cluster using Docker:

```shell
docker run -d --rm --name zookeeper -p 2181:2181 -p 2888:2888 -p 3888:3888 debezium/zookeeper:${DEBEZIUM_VERSION}

docker run -d --rm --name kafka -p 9092:9092 --link zookeeper -e ZOOKEEPER_CONNECT=zookeeper:2181 debezium/kafka:${DEBEZIUM_VERSION}

docker run -d --rm --name postgres -p 6432:5432 -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres debezium/postgres

docker run -d --rm --name elastic -p 9200:9200 -e http.host=0.0.0.0 -e transport.host=127.0.0.1 -e xpack.security.enabled=false -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" docker.elastic.co/elasticsearch/elasticsearch:7.3.0

docker run -d --rm --name connect -p 8083:8083 -p 5005:5005 --link kafka --link postgres --link elastic -e BOOTSTRAP_SERVERS=kafka:9092 -e GROUP_ID=1 -e CONFIG_STORAGE_TOPIC=my_connect_configs -e OFFSET_STORAGE_TOPIC=my_connect_offsets -e STATUS_STORAGE_TOPIC=my_connect_statuses debezium/connect-jdbc-es:${DEBEZIUM_VERSION}
```

### Setup with Docker Compose
Alternative, we can setup the entire cluster with Docker Compose using the following `docker-compose.yaml` file:

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

Now we start every service in the topology as follows:

```shell
export DEBEZIUM_VERSION=2.1
docker-compose -f docker-compose.yaml up
```

### Check everything is running
Before going any further, we neeed to check that every service is up and running:

```shell
$ docker ps | grep debezium
2792950fced9   debezium/connect-jdbc-es:2.1                                                                                   "/docker-entrypoint.…"   35 seconds ago       Up 33 seconds           127.0.0.1:5005->5005/tcp, 127.0.0.1:8083->8083/tcp, 9092/tcp                   connect
ddb60a7cc254   debezium/postgres                                                                                              "docker-entrypoint.s…"   About a minute ago   Up About a minute       127.0.0.1:6432->5432/tcp                                                       postgres
0ccb46011ffa   debezium/kafka:2.1                                                                                             "/docker-entrypoint.…"   About a minute ago   Up About a minute       127.0.0.1:9092->9092/tcp                                                       kafka
cca024019c84   debezium/zookeeper:2.1                                                                                         "/docker-entrypoint.…"   About a minute ago   Up About a minute       127.0.0.1:2181->2181/tcp, 127.0.0.1:2888->2888/tcp, 127.0.0.1:3888->3888/tcp   zookeeper
964282a73ee3   debezium/connect:2.1                                                                                           "/docker-entrypoint.…"   4 days ago           Up 4 days               8083/tcp, 9092/tcp                                                             agitated_mccarthy
```


## Register Connectors with Debezium
In this section we will register the Posgres source and Elasticsearch sink connectors with the Debezium service.

First, check the Kafka Connect service is up and running

```shell
$ curl -H "Accept:application/json" localhost:8083/
{"version":"3.3.1","commit":"e23c59d00e687ff5","kafka_cluster_id":"UBy0Y35cSfOg-Ltt4kBK3g"}
```

Then, check the current list of runing connectors (we should be empty at this point)

```shell
$ curl -H "Accept:application/json" localhost:8083/connectors/
[]
```

### Register Postgres source
The following `pg-source.json` configuration file contains details for Debezium on how to access Postgres (shema, table, etc.), what topic to use for streaming the data and how to transform the transactions:

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

We can register this source connector to read from Postgres as follows:

```shell
$ curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @pg-source.json

{"name":"pg-source","config":{"connector.class":"io.debezium.connector.postgresql.PostgresConnector","tasks.max":"1","database.hostname":"postgres","database.port":"5432","database.user":"postgres","database.password":"postgres","database.dbname":"postgres","topic.prefix":"dbserver1","schema.include.list":"inventory","schema.history.internal.kafka.bootstrap.servers":"kafka:9092","schema.history.internal.kafka.topic":"schema-changes.inventory","transforms":"route","transforms.route.type":"org.apache.kafka.connect.transforms.RegexRouter","transforms.route.regex":"([^.]+)\\.([^.]+)\\.([^.]+)","transforms.route.replacement":"$3","name":"pg-source"},"tasks":[],"type":"source"}
```

Then, check that the Postgres connector is created:


```shell
$ curl -H "Accept:application/json" localhost:8083/connectors/
["pg-source"]
```

And check that the source connector is running:

```shell
$ curl localhost:8083/connectors/pg-source/status
{"name":"pg-source","connector":{"state":"RUNNING","worker_id":"172.17.0.19:8083"},"tasks":[{"id":0,"state":"RUNNING","worker_id":"172.17.0.19:8083"}],"type":"source"}
```

### Register Elasticsearch sink
The following `es-sink.json` configuration file contains details for Debezium to write events to Elasticsearch (index, documents, etc.) and what Kafka topic to read from:


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

Similarly to Postgres source, We can register this connector to write into Elasticsearch as follows:

```shell
$ curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @es-sink.json

{"name":"elastic-sink","config":{"connector.class":"io.confluent.connect.elasticsearch.ElasticsearchSinkConnector","tasks.max":"1","topics":"customers","connection.url":"http://elastic:9200","transforms":"unwrap,key","transforms.unwrap.type":"io.debezium.transforms.ExtractNewRecordState","transforms.unwrap.drop.tombstones":"false","transforms.key.type":"org.apache.kafka.connect.transforms.ExtractField$Key","transforms.key.field":"id","key.ignore":"false","type.name":"customer","behavior.on.null.values":"delete","name":"elastic-sink"},"tasks":[],"type":"sink"}
```

Then, check that the connectors list is updated with the new Elasticsearch sink:

```shell
$ curl -H "Accept:application/json" localhost:8083/connectors/
["elastic-sink","pg-source"]
```

And check that the sink connector is running:

```shell
$ curl localhost:8083/connectors/elastic-sink/status

{"name":"elastic-sink","connector":{"state":"RUNNING","worker_id":"172.17.0.19:8083"},"tasks":[{"id":0,"state":"RUNNING","worker_id":"172.17.0.19:8083"}],"type":"sink"}
```

## Populate Postgres with Data
To test our pipeline, we need to populate some Data in Postgres and then check that it landed as expected in Elasticsearch.

We can modify records in the database via Postgres client as follows:

```shell
$ docker exec -it --env PGOPTIONS="--search_path=inventory" postgres /bin/bash -c 'psql -U $POSTGRES_USER postgres'
postgres=# 
```

Then run few queries to populate Postgres with Data (based on [inventory.sql](https://github.com/debezium/container-images/blob/main/examples/postgres/3.0/inventory.sql))

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
Now we can check the Postgres data changes are available in Elasticsearch by simply listing the objects in our index `customers`.

```shell
curl 'http://localhost:9200/customers/_search?pretty'
```

The output would look something like this:

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
If the services where started individually with `docker run` then we can stop them as follows:

```shell
docker stop connect
docker stop kafka
docker stop zookeeper
docker stop elastic
docker stop postgres
```

Alternatively, if the services were started with Docker compose we simply stop the cluster as follows:

```shell
# Shut down the cluster
$ docker-compose -f docker-compose.yaml down
```

## That's all folks
In this article, we saw how to configure Debezium to stream WAL transactions from Postgres to Elasticsearch.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
