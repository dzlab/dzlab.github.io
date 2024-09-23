---
layout: post
comments: true
title: From Postgres to Kafka throw Debezium 
excerpt: Setup CDC pipeline with Debezium to move data from Postgres to Kafka
categories: debezium
tags: [docker,postgres,kafka]
toc: true
img_excerpt:
---

<img align="left" src="/assets/logos/icons8-docker.svg" width="150" />
<img align="center" src="/assets/logos/debeziumio-ar21.svg" width="200" />
<br/>


```shell
export DEBEZIUM_VERSION=2.1
docker run -d --rm --name zookeeper -p 2181:2181 -p 2888:2888 -p 3888:3888 debezium/zookeeper:${DEBEZIUM_VERSION}

docker run -d --rm --name kafka -p 9092:9092 --link zookeeper -e ZOOKEEPER_CONNECT=zookeeper:2181 debezium/kafka:${DEBEZIUM_VERSION}

docker run -d --rm --name postgres -p 6432:5432 -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres debezium/postgres

docker run -d --rm --name connect -p 8083:8083 -p 5005:5005 --link kafka --link postgres -e BOOTSTRAP_SERVERS=kafka:9092 -e GROUP_ID=1 -e CONFIG_STORAGE_TOPIC=my_connect_configs -e OFFSET_STORAGE_TOPIC=my_connect_offsets -e STATUS_STORAGE_TOPIC=my_connect_statuses debezium/connect:${DEBEZIUM_VERSION}
```

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

Start the topology as defined in https://debezium.io/documentation/reference/stable/tutorial.html

```shell
export DEBEZIUM_VERSION=2.1
docker-compose -f docker-compose.yaml up
```

```shell
$ docker ps | grep debezium
f39144cbc7dc   debezium/connect:3.0                                                                                           "/docker-entrypoint.…"   About a minute ago   Up About a minute       8778/tcp, 127.0.0.1:8083->8083/tcp, 9092/tcp                                   connect
5a5af3f80754   debezium/postgres                                                                                              "docker-entrypoint.s…"   3 minutes ago        Up 3 minutes            127.0.0.1:6432->5432/tcp                                                       postgres
3b3c4302436d   debezium/kafka:3.0                                                                                             "/docker-entrypoint.…"   4 minutes ago        Up 4 minutes            127.0.0.1:9092->9092/tcp                                                       kafka
cfb7ab661b38   debezium/zookeeper:3.0                                                                                         "/docker-entrypoint.…"   4 minutes ago        Up 4 minutes            127.0.0.1:2181->2181/tcp, 127.0.0.1:2888->2888/tcp, 127.0.0.1:3888->3888/tcp   zookeeper
```

## Step 5 Start Debezium Kafka Connect service

```shell
$ curl -H "Accept:application/json" localhost:8083/
{"version":"3.3.1","commit":"e23c59d00e687ff5","kafka_cluster_id":"Z6t0i8sNT1W9-0eQ41gUPQ"}
```

```shell
$ curl -H "Accept:application/json" localhost:8083/connectors/
[]
```

Register source

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
        "schema.include.list": "inventory"
    }
}
```

I validated my config by

```shell
$ curl -s -X PUT -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connector-plugins/io.debezium.connector.postgresql.PostgresConnector/config/validate -d @connect-config.json | jq

{
  "name": "io.debezium.connector.postgresql.PostgresConnector",
  "error_count": 0,
. . .
```

Start Postgres connector

```shell
$ curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @pg-source.json

{"name":"pg-source","config":{"connector.class":"io.debezium.connector.postgresql.PostgresConnector","tasks.max":"1","database.hostname":"postgres","database.port":"5432","database.user":"postgres","database.password":"postgres","database.dbname":"postgres","topic.prefix":"dbserver1","schema.include.list":"inventory","name":"pg-source"},"tasks":[],"type":"source"}
```

Check that the connector is created:


```shell
$ curl -H "Accept:application/json" localhost:8083/connectors/
["pg-source"]
```

Check that the connector is running:

```shell
$ curl localhost:8083/connectors/pg-source/status
{"name":"pg-source","connector":{"state":"RUNNING","worker_id":"172.17.0.18:8083"},"tasks":[{"id":0,"state":"RUNNING","worker_id":"172.17.0.18:8083"}],"type":"source"}
```

The first time it connects to a PostgreSQL server, Debezium takes a [consistent snapshot](https://debezium.io/documentation/reference/1.6/connectors/postgresql.html#postgresql-snapshots) of the tables selected for replication, so you should see that the pre-existing records in the replicated table are initially pushed into your Kafka topic:


## Kafka

```shell

# Consume messages from a Debezium topic
$ docker exec -it kafka /kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server kafka:9092 \
    --from-beginning \
    --property print.key=true \
    --topic dbserver1.inventory.customers
```

## Postgres

```shell
# Modify records in the database via Postgres client
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

logs from `connect` container showing how Debezium is talking first snapshot from .

```
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

```shell
$ docker run -it --name watcher --rm --link zookeeper:zookeeper debezium/kafka watch-topic -a -k dbserver1.public.dumb_table

docker exec kafka watch-topic -a -k dbserver1.public.dumb_table
```

```shell
# Shut down the cluster
$ docker-compose -f docker-compose.yaml down
```

## Resources
- https://hub.docker.com/r/debezium/connect
- https://github.com/debezium/container-images/blob/main/examples/postgres/2.1/Dockerfile
- https://github.com/debezium/debezium-examples/blob/main/tutorial/register-postgres.json
- https://github.com/debezium/debezium-examples/tree/main/tutorial#using-postgres
- https://github.com/debezium/debezium-examples/blob/main/tutorial/docker-compose-postgres.yaml

- https://docs.confluent.io/kafka-connectors/debezium-postgres-source/current/overview.html
- https://debezium.io/documentation/reference/tutorial.html

- https://www.crunchydata.com/blog/postgresql-change-data-capture-with-debezium
- https://medium.com/@tilakpatidar/streaming-data-from-postgresql-to-kafka-using-debezium-a14a2644906d
- https://materialize.com/docs/ingest-data/postgres/debezium/#debezium-15-t1


### debezium-jdbc-es
- https://debezium.io/blog/2018/01/17/streaming-to-elasticsearch/
- https://medium.com/dana-engineering/streaming-data-changes-in-mysql-into-elasticsearch-using-debezium-kafka-and-confluent-jdbc-sink-8890ad221ccf
- https://github.com/debezium/debezium-examples/blob/main/unwrap-smt/docker-compose-es.yaml
- https://stackoverflow.com/questions/65488883/trying-to-configure-debezium-image-for-elasticsearch-sink
- https://github.com/debezium/debezium-examples/blob/main/unwrap-smt/debezium-jdbc-es/Dockerfile