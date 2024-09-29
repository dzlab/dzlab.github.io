---
layout: post
comments: true
title: Streaming Data changes from Postgres to Elasticsearch
excerpt: Using logical replication with wal2json to stream data from Postgres to Elasticsearch
categories: debezium
tags: [docker,postgres,elasticsearch]
toc: true
img_excerpt:
---

`Dockerfile-postgres`

```Dockerfile
FROM postgres:16

RUN apt update && apt install -y postgresql-16-wal2json postgresql-contrib
```

`docker-compose.yaml`

```yml
version: '3.7'
services:
  db:
    container_name: db
    build:
      context: .
      dockerfile: Dockerfile-postgres
    restart: always
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=inventory
    ports:
      - '6432:5432'
    volumes: 
      - ./data:/var/lib/postgresql/data/
      - ./stream:/stream
  es:
    container_name: es
    image: docker.elastic.co/elasticsearch/elasticsearch:7.3.0
    ports:
     - "9200:9200"
    environment:
     - http.host=0.0.0.0
     - transport.host=127.0.0.1
     - xpack.security.enabled=false
     - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
```

docker-compose up -d

```shell
bachir@(dev239)~/cdc/pg-wal2json$ docker-compose up -d   
WARNING: The Docker Engine you're using is running in swarm mode.

Compose does not use swarm mode to deploy services to multiple nodes in a swarm. All containers will be scheduled on the current node.

To deploy your application across the swarm, use `docker stack deploy`.

Creating network "pg-wal2json_default" with the default driver
Building postgres
Step 1/2 : FROM postgres:16
 ---> 2490d47edbe0
Step 2/2 : RUN apt update && apt install -y postgresql-16-wal2json postgresql-contrib
 ---> Using cache
 ---> 33d5e697f329

Successfully built 33d5e697f329
Successfully tagged pg-wal2json_postgres:latest

Creating db ... done
```


docker-compose exec db psql -U postgres -c 'SHOW config_file'
```shell
bachir@(dev239)~/cdc/pg-wal2json$ docker-compose exec db psql -U postgres -c 'SHOW config_file'
               config_file                
------------------------------------------
 /var/lib/postgresql/data/postgresql.conf
(1 row)

```


ALTER SYSTEM SET wal_level = 'logical';


```shell
bachir@(dev239)~/cdc/pg-wal2json$ docker-compose exec db psql -U postgres                      
psql (17.0 (Debian 17.0-1.pgdg120+1), server 16.4 (Debian 16.4-1.pgdg120+2))
Type "help" for help.

postgres=# show wal_level;
 wal_level 
-----------
 replica
(1 row)

postgres=# show max_replication_slots;
 max_replication_slots 
-----------------------
 10
(1 row)

postgres=# show shared_preload_libraries;
 shared_preload_libraries 
--------------------------

(1 row)

postgres=# ALTER SYSTEM SET wal_level = 'logical';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET  shared_preload_libraries = 'wal2json';
ALTER SYSTEM
postgres=# \q
```

Restart postgres

```shell
$ docker-compose restart db
Restarting db ... done
```

## Setup Replication Slot

```shell
$ docker-compose exec db psql -U postgres -d inventory
```

```sql
SELECT * FROM pg_create_logical_replication_slot('regression_slot', 'wal2json');
```

```
    slot_name    |    lsn    
-----------------+-----------
 regression_slot | 0/1953610
(1 row)
```

```sql
SELECT slot_name, plugin, slot_type, database, active, restart_lsn, confirmed_flush_lsn FROM pg_replication_slots;
```

```
    slot_name    |  plugin  | slot_type | database  | active | restart_lsn | confirmed_flush_lsn 
-----------------+----------+-----------+-----------+--------+-------------+---------------------
 regression_slot | wal2json | logical   | inventory | f      | 0/19535D8   | 0/1953610
(1 row)
```

## Activate Logical Replication Slot
```shell
docker-compose exec db pg_recvlogical -d inventory -U postgres --slot regression_slot --start -o pretty-print=1 -f /stream/regresstion-slot.jsonl
```


```shell
$ docker-compose exec db psql -U postgres -d inventory
```

```
inventory=# SELECT slot_name, plugin, slot_type, database, active, restart_lsn, confirmed_flush_lsn FROM pg_replication_slots;

    slot_name    |  plugin  | slot_type | database  | active | restart_lsn | confirmed_flush_lsn 
-----------------+----------+-----------+-----------+--------+-------------+---------------------
 regression_slot | wal2json | logical   | inventory | t      | 0/19536C0   | 0/19536F8
```

tail -f stream/regresstion-slot.jsonl

## Dummy Data

To populate Postgres with Data, we can connect to the Postgres containers and open a client shell to execute the data SQL queries:


```shell
$ docker-compose exec db psql -U postgres -d inventory
inventory=# 
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

New record
Insert a new record into Postgres:

```shell
$ docker-compose exec db psql -U postgres -d inventory \
  -c "insert into inventory.customers values(default, 'John', 'Doe', 'john.doe@example.com')"
```

Record update
Update a record in MySQL:

```shell
$ docker-compose exec db psql -U postgres -d inventory \
  -c "update inventory.customers set first_name='Jane', last_name='Roe' where last_name='Doe'"
```

```shell
$ docker-compose exec db psql -U postgres -d inventory \
  -c "delete from inventory.customers where email='john.doe@example.com';"
```


```shell
ES_INDEX=customers
ES_URL="http://localhost:9200/$ES_INDEX"
```

To create an Elasticsearch index, you can use the Create Index API. Here's how to do it:
Basic index creation:

```shell
$ curl -X PUT $ES_URL

{"acknowledged":true,"shards_acknowledged":true,"index":"customers"}
```

```shell
cat stream/regresstion-slot.jsonl | \
  jq -c '. | select(.change | length > 0) | .' | \
  jq '.change | flatten'
  curl -X POST $ES_URL/_doc -H "Content-Type: application/json" --data-binary @-
```


Let's break down the command:
The echo command outputs the JSON object.
The pipe (|) sends the output to curl.
curl sends a POST request to the Elasticsearch update endpoint.
-H "Content-Type: application/json" sets the content type header.
--data-binary @- tells curl to read the request body from stdin.
Customize the JSON object:
Modify the JSON object to include the fields you want to upsert. The "doc_as_upsert": true flag tells Elasticsearch to perform an upsert operation.
Adjust the Elasticsearch endpoint:
Replace your_index with the name of your index and your_document_id with the ID of the document you want to upsert.
Handle authentication:
If your Elasticsearch instance requires authentication, add the appropriate credentials to the curl command.

```shell
sudo cat stream/regresstion-slot.jsonl | \
  jq -c '. | select(.change | length > 0) | .' | \
  jq -r '.change[] | @json' | \
  jq -c '[.columnnames, .columnvalues] | transpose | map({(.[0]): .[1]}) | add'
```

does the following `jq -c '[.columnnames, .columnvalues] | transpose | map({(.[0]): .[1]}) | add'`
Here's a breakdown of how this jq command works:
[.a, .b] creates an array containing the values of keys "a" and "b".
transpose converts the array of arrays into an array of paired elements.
map({(.): .[1]}) transforms each pair into an object with the first element as the key and the second as the value.
add combines all the individual objects into a single object.

```shell
curl 'http://localhost:9200/customers/_search?pretty'
```

# Shut down the cluster

End the application:


```shell
$ docker-compose down

Stopping db ... done
Stopping es ... done
Removing db ... done
Removing es ... done
Removing network pg-wal2json_default
```

Using filebeat
- https://github.com/rmalchow/docker-json-filebeat-example
- https://www.sarulabs.com/post/5/2019-08-12/sending-docker-logs-to-elasticsearch-and-kibana-with-filebeat.html
