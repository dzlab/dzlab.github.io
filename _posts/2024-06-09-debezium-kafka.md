---
layout: post
comments: true
title: From Postgres to Kafka through Debezium 
excerpt: Setup CDC pipeline with Debezium to move data from Postgres to Kafka
categories: debezium
tags: [docker,postgres,kafka]
toc: true
img_excerpt:
---

<img align="left" src="/assets/logos/icons8-docker.svg" width="150" />
<img align="center" src="/assets/logos/debeziumio-ar21.svg" width="400" />
<br/>


[Change Data Capture (CDC)](https://en.wikipedia.org/wiki/Change_data_capture) allows changes propagation from a Data Source to downstream sinks. In particular, CDC is to capture row-level changes resulting from INSERT, UPDATE and DELETE operations in the upstream Relational Databses (e.g. Postgres) and propage these changes to analytical warehouse or Data Lakes.
By leveraging [Write-Ahead Log (WAL)](https://en.wikipedia.org/wiki/Write-ahead_logging), CDC does not modify the source database and as a result does not impact performance unlike other propagation techniques: triggers or log tables.

[Debezium](https://debezium.io/) is an open source implementation of CDC. It is built upon the [Apache Kafka](https://kafka.apache.org/) project, it streams the changes into Kafka topics using the [Kafka Connect](https://www.confluent.io/product/connectors/) API.


In the remaining of this post, we will use Debezium to propagate CDC data out of Postgres into Kafka. 

## Toplogy

The components of our cluster that are need to show case the use of Debezium are as follows:
- Postgres - a Relational Database for storing the data and representing the changes source
- [Apache Kafka](https://kafka.apache.org/) - used to create a messaging topic which will store the CDC data coming from the database.
- [Apache Zookeeper](https://zookeeper.apache.org/) - a centralized service that provides distributed synchronization. It is used by Kafka to store configuration management.
- [Debezium](https://github.com/debezium/debezium) — a CDC tool based on [Kafka Connect](https://www.confluent.io/product/connectors/) to stream WAL data from source system to Kafka.


### Setup With Docker
In this section, we start each components of the cluster using Docker:


```shell
export DEBEZIUM_VERSION=2.1

# Start Zookeeper service
docker run -d --rm --name zookeeper -p 2181:2181 -p 2888:2888 -p 3888:3888 debezium/zookeeper:${DEBEZIUM_VERSION}

# Start Kafka service
docker run -d --rm --name kafka -p 9092:9092 --link zookeeper -e ZOOKEEPER_CONNECT=zookeeper:2181 debezium/kafka:${DEBEZIUM_VERSION}

# Start Postgres service
docker run -d --rm --name postgres -p 6432:5432 -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres debezium/postgres

# Start Debezium Kafka Connect service
docker run -d --rm --name connect -p 8083:8083 -p 5005:5005 --link kafka --link postgres -e BOOTSTRAP_SERVERS=kafka:9092 -e GROUP_ID=1 -e CONFIG_STORAGE_TOPIC=my_connect_configs -e OFFSET_STORAGE_TOPIC=my_connect_offsets -e STATUS_STORAGE_TOPIC=my_connect_statuses debezium/connect:${DEBEZIUM_VERSION}
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
  connect:
    image: debezium/connect:${DEBEZIUM_VERSION}
    ports:
     - 8083:8083
     - 5005:5005
    links:
     - kafka
     - postgres
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

f39144cbc7dc   debezium/connect:3.0                                                                                           "/docker-entrypoint.…"   About a minute ago   Up About a minute       8778/tcp, 127.0.0.1:8083->8083/tcp, 9092/tcp                                   connect
5a5af3f80754   debezium/postgres                                                                                              "docker-entrypoint.s…"   3 minutes ago        Up 3 minutes            127.0.0.1:6432->5432/tcp                                                       postgres
3b3c4302436d   debezium/kafka:3.0                                                                                             "/docker-entrypoint.…"   4 minutes ago        Up 4 minutes            127.0.0.1:9092->9092/tcp                                                       kafka
cfb7ab661b38   debezium/zookeeper:3.0                                                                                         "/docker-entrypoint.…"   4 minutes ago        Up 4 minutes            127.0.0.1:2181->2181/tcp, 127.0.0.1:2888->2888/tcp, 127.0.0.1:3888->3888/tcp   zookeeper
```

## Register Source with Debezium
Debezium is deployed as a set of Kafka Connect-compatible connectors, so we first need to configure a Postgres connector and then start it.

First, check the Kafka Connect is up and running

```shell
$ curl -H "Accept:application/json" localhost:8083/
{"version":"3.3.1","commit":"e23c59d00e687ff5","kafka_cluster_id":"Z6t0i8sNT1W9-0eQ41gUPQ"}
```

Then, check the current list of runing connectors (we should be empty at this point)

```shell
$ curl -H "Accept:application/json" localhost:8083/connectors/
[]
```

Now, we can register a connector to read from Postgres. The following `pg-source.json` configuration file contains details for Debezium on how to access Postgres (shema, table, etc.) and what topic to use for streaming the data:

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
        "schema.include.list": "inventory"
    }
}
```

Before registering the connector, we can validate the `config` part as follows:

```shell
$ curl -s -X PUT -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connector-plugins/io.debezium.connector.postgresql.PostgresConnector/config/validate -d @connect-config.json | jq

{
  "name": "io.debezium.connector.postgresql.PostgresConnector",
  "error_count": 0,
. . .
```

Once we are sure the configuration is valid, i.e. there is zero validation errors, we can submit the configuration to start Postgres connector

```shell
$ curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @pg-source.json

{"name":"pg-source","config":{"connector.class":"io.debezium.connector.postgresql.PostgresConnector","tasks.max":"1","database.hostname":"postgres","database.port":"5432","database.user":"postgres","database.password":"postgres","database.dbname":"postgres","topic.prefix":"dbserver1","schema.include.list":"inventory","name":"pg-source"},"tasks":[],"type":"source"}
```

We can check that the new connector was created:


```shell
$ curl -H "Accept:application/json" localhost:8083/connectors/
["pg-source"]
```

And also check that the connector is running properly

```shell
$ curl localhost:8083/connectors/pg-source/status
{"name":"pg-source","connector":{"state":"RUNNING","worker_id":"172.17.0.18:8083"},"tasks":[{"id":0,"state":"RUNNING","worker_id":"172.17.0.18:8083"}],"type":"source"}
```

## Populate Postgres with Data

To populate Postgres with Data, we can connect to the Postgres containers and open a client shell to execute the data SQL queries:


```shell
$ docker exec -it --env PGOPTIONS="--search_path=inventory" postgres /bin/bash -c 'psql -U $POSTGRES_USER postgres'
postgres=# 
```

The following are few example queries that can be used to populate Postgres with Data (based on [inventory.sql](https://github.com/debezium/container-images/blob/main/examples/postgres/3.0/inventory.sql))

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

The first time Debezium connects to a Postgres, it will take a [consistent snapshot](https://debezium.io/documentation/reference/1.6/connectors/postgresql.html#postgresql-snapshots) of the tables selected for replication, so we should expect to see that the pre-existing records in the replicated table are initially pushed into our Kafka topic.

## Kafka
Now we can check the Postgres changes are available in Kafka.

Start a Kafka client to list the topics available in our Kafka service:

```shell
$ docker run -it --rm --link kafka --name watcher debezium/connect:${DEBEZIUM_VERSION} /kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --list 
```

We can consume messages from the Kafka topic created by Debezium as follows:

```shell
$ docker run -it --rm --link kafka --name watcher debezium/connect:${DEBEZIUM_VERSION} /kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server kafka:9092 \
    --from-beginning \
    --property print.key=true \
    --topic dbserver1.inventory.customers
```

After a while, Kafka consumer will start printing the Postgres transactions it receives from the kafka topic `dbserver1.inventory.customers`

```json
. . .
  "payload": {
    "before": null,
    "after": {
      "id": 1004,
      "first_name": "Anne",
      "last_name": "Kretchmar",
      "email": "annek@noanswer.org"
    },
    "source": {
      "version": "2.1.4.Final",
      "connector": "postgresql",
      "name": "dbserver1",
      "ts_ms": 1727118551080,
      "snapshot": "last",
      "db": "postgres",
      "sequence": "[null,\"23760688\"]",
      "schema": "inventory",
      "table": "customers",
      "txId": 608,
      "lsn": 23760688,
      "xmin": null
    },
    "op": "r",
    "ts_ms": 1727118551116,
    "transaction": null
  }
}
```


We can also confirm that Debezium is running properly and streaming data to Kafka topic by checking the logs from `connect` container with `docker logs -f connect`.

For instance, the following snippets shows how Debezium is creating a first snapshot from Postgres, specifically the `inventory.customers` table:

```shell
024-09-22 21:43:30,253 INFO   Postgres|dbserver1|snapshot  Snapshot step 1 - Preparing   [io.debezium.relational.RelationalSnapshotChangeEventSource]
2024-09-22 21:43:30,272 INFO   Postgres|dbserver1|snapshot  Snapshot step 2 - Determining captured tables   [io.debezium.relational.RelationalSnapshotChangeEventSource]
2024-09-22 21:43:30,273 INFO   Postgres|dbserver1|snapshot  Adding table inventory.customers to the list of capture schema tables   [io.debezium.relational.RelationalSnapshotChangeEventSource]
2024-09-22 21:43:30,273 INFO   Postgres|dbserver1|snapshot  Snapshot step 3 - Locking captured tables [inventory.customers]   [io.debezium.relational.RelationalSnapshotChangeEventSource]
2024-09-22 21:43:30,273 INFO   Postgres|dbserver1|snapshot  Snapshot step 4 - Determining snapshot offset   [io.debezium.relational.RelationalSnapshotChangeEventSource]
2024-09-22 21:43:30,273 INFO   Postgres|dbserver1|snapshot  Creating initial offset context   [io.debezium.connector.postgresql.PostgresSnapshotChangeEventSource]
2024-09-22 21:43:30,274 INFO   Postgres|dbserver1|snapshot  Read xlogStart at 'LSN{0/16ABB20}' from transaction '579'   [io.debezium.connector.postgresql.PostgresSnapshotChangeEventSource]
2024-09-22 21:43:30,274 INFO   Postgres|dbserver1|snapshot  Read xlogStart at 'LSN{0/16ABB20}' from transaction '579'   [io.debezium.connector.postgresql.PostgresSnapshotChangeEventSource]
2024-09-22 21:43:30,274 INFO   Postgres|dbserver1|snapshot  Snapshot step 5 - Reading structure of captured tables   [io.debezium.relational.RelationalSnapshotChangeEventSource]
2024-09-22 21:43:30,274 INFO   Postgres|dbserver1|snapshot  Reading structure of schema 'inventory' of catalog 'postgres'   [io.debezium.connector.postgresql.PostgresSnapshotChangeEventSource]
2024-09-22 21:43:30,289 INFO   Postgres|dbserver1|snapshot  Snapshot step 6 - Persisting schema history   [io.debezium.relational.RelationalSnapshotChangeEventSource]
2024-09-22 21:43:30,289 INFO   Postgres|dbserver1|snapshot  Snapshot step 7 - Snapshotting data   [io.debezium.relational.RelationalSnapshotChangeEventSource]
2024-09-22 21:43:30,289 INFO   Postgres|dbserver1|snapshot  Snapshotting contents of 1 tables while still in transaction   [io.debezium.relational.RelationalSnapshotChangeEventSource]
2024-09-22 21:43:30,289 INFO   Postgres|dbserver1|snapshot  Exporting data from table 'inventory.customers' (1 of 1 tables)   [io.debezium.relational.RelationalSnapshotChangeEventSource]
2024-09-22 21:43:30,289 INFO   Postgres|dbserver1|snapshot  	 For table 'inventory.customers' using select statement: 'SELECT "id", "first_name", "last_name", "email" FROM "inventory"."customers"'   [io.debezium.relational.RelationalSnapshotChangeEventSource]
2024-09-22 21:43:30,292 INFO   Postgres|dbserver1|snapshot  	 Finished exporting 4 records for table 'inventory.customers'; total duration '00:00:00.003'   [io.debezium.relational.RelationalSnapshotChangeEventSource]
2024-09-22 21:43:30,292 INFO   Postgres|dbserver1|snapshot  Snapshot - Final stage   [io.debezium.pipeline.source.AbstractSnapshotChangeEventSource]
2024-09-22 21:43:30,292 INFO   Postgres|dbserver1|snapshot  Snapshot completed   [io.debezium.pipeline.source.AbstractSnapshotChangeEventSource]
2024-09-22 21:43:30,292 INFO   Postgres|dbserver1|snapshot  Snapshot ended with SnapshotResult [status=COMPLETED, offset=PostgresOffsetContext [sourceInfoSchema=Schema{io.debezium.connector.postgresql.Source:STRUCT}, sourceInfo=source_info[server='dbserver1'db='postgres', lsn=LSN{0/16ABB20}, txId=579, timestamp=2024-09-22T21:43:30.253778Z, snapshot=FALSE, schema=inventory, table=customers], lastSnapshotRecord=true, lastCompletelyProcessedLsn=null, lastCommitLsn=null, streamingStoppingLsn=null, transactionContext=TransactionContext [currentTransactionId=null, perTableEventCount={}, totalEventCount=0], incrementalSnapshotContext=IncrementalSnapshotContext [windowOpened=false, chunkEndPosition=null, dataCollectionsToSnapshot=[], lastEventKeySent=null, maximumKey=null]]]   [io.debezium.pipeline.ChangeEventSourceCoordinator]
```

## Shut down the cluster

If the services where started individually with `docker run` then we can stop them as follows:

```shell
docker stop connect
docker stop kafka
docker stop zookeeper
docker stop postgres
```

Alternatively, if the services were started with Docker compose we simply stop the cluster as follows:

```shell
$ docker-compose -f docker-compose.yaml down
```

## That's all folks
In this article, we saw how to configure Debezium to propagate WAL transactions from Postgres to Kafka.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
