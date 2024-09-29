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

On a separate shell activate Logical Replication Slot with `pg_recvlogical`
```shell
$ docker-compose exec db pg_recvlogical -d inventory -U postgres --slot regression_slot --start -o pretty-print=1 -f /stream/regresstion-slot.jsonl
```

Going back to the SQL shell and check 

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


To create an Elasticsearch index, you can use the Create Index API. Here's how to do it:
Basic index creation:

```shell
$ curl -X PUT http://localhost:9200/customers

{"acknowledged":true,"shards_acknowledged":true,"index":"customers"}
```

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

```shell
$ cat ./stream/regresstion-slot.jsonl | jq -c | python process.py
```
```json
{'kind': 'insert', 'schema': 'inventory', 'table': 'customers', 'id': 1001, 'first_name': 'Sally', 'last_name': 'Thomas', 'email': 'sally.thomas@acme.com'}
{'kind': 'insert', 'schema': 'inventory', 'table': 'customers', 'id': 1002, 'first_name': 'George', 'last_name': 'Bailey', 'email': 'gbailey@foobar.com'}
{'kind': 'insert', 'schema': 'inventory', 'table': 'customers', 'id': 1003, 'first_name': 'Edward', 'last_name': 'Walker', 'email': 'ed@walker.com'}
{'kind': 'insert', 'schema': 'inventory', 'table': 'customers', 'id': 1004, 'first_name': 'Anne', 'last_name': 'Kretchmar', 'email': 'annek@noanswer.org'}
{'kind': 'insert', 'schema': 'inventory', 'table': 'customers', 'id': 1005, 'first_name': 'John', 'last_name': 'Doe', 'email': 'john.doe@example.com'}
{'kind': 'update', 'schema': 'inventory', 'table': 'customers', 'id': 1005, 'first_name': 'Jane', 'last_name': 'Roe', 'email': 'john.doe@example.com', 'old': {'id': 1005, 'first_name': 'John', 'last_name': 'Doe', 'email': 'john.doe@example.com'}}
{'kind': 'delete', 'schema': 'inventory', 'table': 'customers', 'old': {'id': 1005, 'first_name': 'Jane', 'last_name': 'Roe', 'email': 'john.doe@example.com'}}
```

```shell
curl 'http://localhost:9200/customers/_search?pretty'
```

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

Using filebeat
- https://github.com/rmalchow/docker-json-filebeat-example
- https://www.sarulabs.com/post/5/2019-08-12/sending-docker-logs-to-elasticsearch-and-kibana-with-filebeat.html
