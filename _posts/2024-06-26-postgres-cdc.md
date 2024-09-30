---
layout: post
comments: true
title: Streaming Data changes from Postgres to Elasticsearch
excerpt: Using logical replication with wal2json to stream data from Postgres to Elasticsearch
categories: debezium
tags: [docker,postgres,elasticsearch]
toc: true
img_excerpt: assets/2024/06/20240626-postgres-wal2json.svg
---


Postgres logical replication enables the streaming of the changes in the write-ahead log (WAL). This functionality uses [Logical Decoding](https://www.postgresql.org/docs/current/logicaldecoding.html) to transform the write-ahead log (WAL) into a format that can be consumed by external applications. This is further extended via a collection of [plugins](https://wiki.postgresql.org/wiki/Logical_Decoding_Plugins):

- **pgoutput:** a built-in plugin that comes with PostgreSQL 10 and later versions. It generates a binary format that can be consumed by clients like Npgsql, Debezium, and others.
- **wal2json:** part of the PostgreSQL contrib package and generates a JSON format that can be easily consumed by applications. It’s widely used and has good support for various programming languages.
- **test_decoding:** part of the PostgreSQL contrib package and generates a text-based format that’s easy to parse. It’s primarily used for testing and debugging purposes.
- **decoder_json:** uses `libjansson` to generate JSON output, providing an alternative to `wal2json`.
- **decoder_raw:** generates a raw, binary format that can be customized for specific use cases.
- **Debezium’s PostgreSQL connector:** provides a Kafka-based logical replication solution, allowing you to stream changes from PostgreSQL to Apache Kafka.
- **Logical Decode:** provides a Java-based implementation for parsing the output of the pgoutput plugin.

In this article, we will setup logical replication to stream changes from Postgres to Elasticsearch. We will use the [wal2json](https://github.com/eulerto/wal2json) plugin to output JSON documents for each change in Postgres WAL. 


## Toplogy

The diagram below illustrates the different components of our cluster:
- Postgres - a Relational Database used as our **Source** and configured for logication replication with the `wal2json` plugin
- Elasticsearch - a Distributed full-text search engine and the **Sink** where WAL changes will end up.
- A python script `process.py` that will continuously consume JSON objects as outputed by the `wal2json` plugin and forward them to Elasticsearch

We will use a separate container for each service. We will mount directories on the host machine as volumes in Postgres to make the WAL available from the host machine. This is simply for convenience of WAL processing.

![Debezium toplogy]({{ "/assets/2024/06/20240626-postgres-wal2json.svg" | absolute_url }})

### Build Docker image for Postgres with wal2json
The `wal2json` plugin is not shipped with Postgres, we need to install it manually. The following Dockerfile `Dockerfile-postgres` uses Postgres base image and then setup `wal2json`:

```Dockerfile
FROM postgres:16

RUN apt update && apt install -y postgresql-16-wal2json postgresql-contrib
```

### Setup services with Docker-compose
The following Docker-compose file `docker-compose.yaml` setup the topology by building the Postgres image on the fly and create the container, as well as configures Elasticsearch

with Docker Compose using the following `docker-compose.yaml` file:


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

Now let's start the topology with `docker-compose up -d`:

```shell
$ docker-compose up -d   

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

## Setup Logical Decoding

To setup logical decoding so that the WAL changes are streamed in JSON, we need to update Postgres configucation file at `postgresql.conf` with the following mininum changes:

```
wal_level = logical
max_replication_slots = 1
shared_preload_libraries = 'wal2json'
```

We can either locate the file and edit it manually:

```shell
$ docker-compose exec db psql -U postgres -c 'SHOW config_file'

               config_file                
------------------------------------------
 /var/lib/postgresql/data/postgresql.conf
(1 row)
```

Alternatively, we can update these settings using SQL queries as follows:

```shell
$ docker-compose exec db psql -U postgres                      

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

After updating the configuration file, we need to restart Postgres for the changes to take effect:

```shell
$ docker-compose restart db

Restarting db ... done
```

## Setup Replication Slot

After configuring the Logical Decoding, next we to set up the replication slot. First, connect to SQL interpreter in Postgres

```shell
$ docker-compose exec db psql -U postgres -d inventory
```

Run the following SQL query to create the replication slot using `wal2json`

```sql
SELECT * FROM pg_create_logical_replication_slot('my_slot', 'wal2json');
```

This query will output something like this:

```
    slot_name    |    lsn    
-----------------+-----------
 my_slot         | 0/1953610
(1 row)
```

Now we run the following query to get more information about replication slot we just created:

```sql
SELECT slot_name, plugin, slot_type, database, active, restart_lsn, confirmed_flush_lsn FROM pg_replication_slots;
```

You could see that the slot we just created is not yet active (see column `active` set to `f` for false):

```
    slot_name    |  plugin  | slot_type | database  | active | restart_lsn | confirmed_flush_lsn 
-----------------+----------+-----------+-----------+--------+-------------+---------------------
 my_slot         | wal2json | logical   | inventory | f      | 0/19535D8   | 0/1953610
(1 row)
```

On a separate shell activate Logical Replication slot with `pg_recvlogical`

```shell
$ docker-compose exec db pg_recvlogical -d inventory -U postgres --slot my_slot --start -o pretty-print=1 -f /stream/my-slot.jsonl
```

Going back to the SQL intererpreter and running the check query we run earlier, we do see now that the slot is active and ready for streaming changes.

```
inventory=# SELECT slot_name, plugin, slot_type, database, active, restart_lsn, confirmed_flush_lsn FROM pg_replication_slots;

    slot_name    |  plugin  | slot_type | database  | active | restart_lsn | confirmed_flush_lsn 
-----------------+----------+-----------+-----------+--------+-------------+---------------------
 my_slot         | wal2json | logical   | inventory | t      | 0/19536C0   | 0/19536F8
```

## Populate Postgres with Data

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

Let's perform more changes to our data so we can get all types of queries (INSERT, UPDATE, DELETE) represented in the WAL. 

For instance, insert a new record:

```shell
$ docker-compose exec db psql -U postgres -d inventory \
  -c "insert into inventory.customers values(default, 'John', 'Doe', 'john.doe@example.com')"
```

Then, update the record we just created:

```shell
$ docker-compose exec db psql -U postgres -d inventory \
  -c "update inventory.customers set first_name='Jane', last_name='Roe' where last_name='Doe'"
```

Finaly, delete the record

```shell
$ docker-compose exec db psql -U postgres -d inventory \
  -c "delete from inventory.customers where email='john.doe@example.com';"
```


## Setup Elasticsearch

We need to create the Elasticsearch index where the WAL transactions will forwarded. We can use the Create Index API for this as follows:

```shell
$ curl -X PUT http://localhost:9200/customers

{"acknowledged":true,"shards_acknowledged":true,"index":"customers"}
```

## CDC stream processing

Finaly, the last piece of the puzzle is setting up the stream processing that captures WAL changes as they are streamed from the replication slot, transform them and then insert them to Elasticsearch.

The following script defines the following:
- `Elasticsearch` helper class to send document INSERT requests to Elasticsearch
- `process_transaction` process a single WAL change and then insert it to Elasticsearch
- `process_input` iterate over a stream of lines coming from the console `STANDARD_INPUT`
- `main` parses the CLI arguments and then starts the stream processing logic

```python
import argparse
import json
import os
import requests
import sys

# Helper class to interact with Elasticsearch
class Elasticsearch:
  def __init__(self, base_url):
    self.base_url = base_url

  def upsert(self, index_name, document):
    headers = {'Content-Type': 'application/json'}
    url = f"{self.base_url}/{index_name}/_doc"
    try:
      response = requests.post(url, data=json.dumps(document), headers=headers)
      response.raise_for_status()
      return response.json()
    except requests.exceptions.RequestException as e:
      print(f"Error writing document to Elasticsearch: {e}")
      return None

# Process a single transaction
def process_transaction(in_obj):
  out_obj = {}
  for key in ['kind', 'schema', 'table']:
    out_obj[key] = in_obj[key]
  if in_obj['kind'] != 'delete':
    for key, value in zip(in_obj['columnnames'], in_obj['columnvalues']):
      out_obj[key] = value
  if 'oldkeys' in in_obj:
    out_obj['old'] = {}
    for key, value in zip(in_obj['oldkeys']['keynames'], in_obj['oldkeys']['keyvalues']):
      out_obj['old'][key] = value
  print(out_obj)
  return out_obj

# Process a file of change transactions
def process_input(es_url):
  es = Elasticsearch(es_url)
  for line in sys.stdin:
    txs = json.loads(line)
    if txs['change'] == []:
      continue
    for tx in txs['change']:
      result = process_transaction(tx)
      es.upsert(result['table'], result)

# Parse CLI arguments
def parse_arguments():
    parser = argparse.ArgumentParser(description="Description of your program")
    parser.add_argument('-u', '--url', default='http://localhost:9200', help='Base URL for Elasticsearch')
    return parser.parse_args()

def main():
    args = parse_arguments()
    print(f'Uploading transactions to {args.url}')
    process_input(args.url)

if __name__ == "__main__":
    main()
```

In a separate shell, start the stream procesing from as follows

```shell
$ cat ./stream/my-slot.jsonl | jq -c | python process.py
```

As changes are writing to `./stream/my-slot.jsonl` by the `pg_recvlogical` process that we started earlier, our `process.py` will transform them into something that looks like the following:

```json
{'kind': 'insert', 'schema': 'inventory', 'table': 'customers', 'id': 1001, 'first_name': 'Sally', 'last_name': 'Thomas', 'email': 'sally.thomas@acme.com'}
{'kind': 'insert', 'schema': 'inventory', 'table': 'customers', 'id': 1002, 'first_name': 'George', 'last_name': 'Bailey', 'email': 'gbailey@foobar.com'}
{'kind': 'insert', 'schema': 'inventory', 'table': 'customers', 'id': 1003, 'first_name': 'Edward', 'last_name': 'Walker', 'email': 'ed@walker.com'}
{'kind': 'insert', 'schema': 'inventory', 'table': 'customers', 'id': 1004, 'first_name': 'Anne', 'last_name': 'Kretchmar', 'email': 'annek@noanswer.org'}
{'kind': 'insert', 'schema': 'inventory', 'table': 'customers', 'id': 1005, 'first_name': 'John', 'last_name': 'Doe', 'email': 'john.doe@example.com'}
{'kind': 'update', 'schema': 'inventory', 'table': 'customers', 'id': 1005, 'first_name': 'Jane', 'last_name': 'Roe', 'email': 'john.doe@example.com', 'old': {'id': 1005, 'first_name': 'John', 'last_name': 'Doe', 'email': 'john.doe@example.com'}}
{'kind': 'delete', 'schema': 'inventory', 'table': 'customers', 'old': {'id': 1005, 'first_name': 'Jane', 'last_name': 'Roe', 'email': 'john.doe@example.com'}}
```

## Verifying the data in Elasticsearch

We can simply verify that the WAL changes had landed in Elasticsearch by querying the `customers` index as follows:

```shell
curl 'http://localhost:9200/customers/_search?pretty'
```

We can entries like this:

```json
      {
        "_index": "customers",
        "_type": "_doc",
        "_id": "Hl72PpIBc0uZl7MqeRNu",
        "_score": 1,
        "_source": {
          "kind": "delete",
          "schema": "inventory",
          "table": "customers",
          "old": {
            "id": 1005,
            "first_name": "Jane",
            "last_name": "Roe",
            "email": "john.doe@example.com"
          }
        }
      }
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

## That's all folks
In this article, we saw how to configure Postgres Logical Decoding to stream WAL transactions out of Postgres in JSON format, then we created a python script to consume the changes in WAL to later insert them into Elasticsearch.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
