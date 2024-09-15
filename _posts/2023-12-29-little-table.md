---
layout: post
comments: true
title: Timeseries Databases LittleTable
excerpt: 
tags: [timeseries,db]
toc: true
img_excerpt:
---


      ,---------------- LittleTable Server --------------.
      |                                                  |
      |         ,------------------,          ,------------------,
Table |------>  | In-Memory Tablet |  ......> | In-Memory Tablet |
insert|         '------------------'          '------------------'   
      |                                                  ^
      |     ,---------------------,                      | flush when 
      |---- | On-Disk Tablet      | <--------------------'  full  
      |     | ts: 1/1 - 1/15      |
      |     | key: sort order     |
      |     '---------------------'
      |
      |     ,---------------------,
      |---- | On-Disk Tablet      |  
      |     | ts: 1/16 - 1/31     |   
      |     | key: sort order     |
      |     '---------------------'
      |
      |           (more tablets)
      |                                                  |
      '--------------------------------------------------'
                                       |
                                  query ---> row
                                       |
                                       V

Key aspects shown:

Table inserts go into in-memory tablets
In-memory tablets get flushed to disk as immutable on-disk tablets
On-disk tablets are partitioned by timestamp and sorted by key
Queries retrieve rows by specifying timestamp and key bounds
This shows the basic log-structured, sorted tablet architecture that allows LittleTable to efficiently store and retrieve time series data.



[LittleTable](https://dl.acm.org/doi/abs/10.1145/3035918.3056102) is a relational database optimized for efficiently storing, querying, and aggregating time-series data.

LittleTable is a relational database that has been in production use at Cisco Meraki since 2008 to store network timeseries data such as usage statistics, event logs, and other metrics from customers' networking devices.


## Architecture
LittleTable employs a log-structured merge tree architecture, storing data in memory using balanced tree tablets which get flushed to disk as immutable tablets. Queries retrieve rows by scanning tablet files and merging sorted result streams.


LittleTable also capitalizes on the reduced consistency and durability needs of the single-writer, append-only data it stores. It uses techniques like infrequent flushing, merging of tables, and not requiring a separate write-ahead log to achieve high performance even on spinning disks, while tolerating occasional data loss.

With appropriately chosen keys, LittleTable sustains over 500,000 rows per second for queries and 42% of peak disk write throughput for inserts. It currently stores 320TB of time-series data across Cisco Meraki's production systems.

It optimizes for time-series data in two key ways:

### Time Clustering
1) By partitioning rows by timestamp, it clusters recent data together for quick access without imposing any penalty for retaining large amounts of historical data.

### Key Sorting
2) By further sorting rows within each timestamp partition by a hierarchically-delineated key, it allows developers to optimize each table's layout on disk based on the type of queries that will be run. For example, usage data can be clustered simultaneously by network, device, and time period.


## Data Model

### Schema Flexibility
LittleTable provides limited schema modification capabilities:

- Append new columns
- Increase column precision 
- Change table TTL
- Recreate table with new schema

Yes, the table schema in LittleTable can be updated to some extent by adding or removing columns. According to the details provided in the paper:

- Clients can append columns to the end of a table's schema to add new columns.

- Clients can also increase the precision of 32-bit integer columns in the schema to 64-bits. 

- The time-to-live (TTL) period of a table can be altered.

- Entire tables can be dropped and recreated with a completely new schema, an approach the authors state they use frequently during new feature development.

However, the paper does not mention the ability to directly remove or delete existing columns from a table's schema. The details around manipulating the schema are limited, but it seems to offer at least some basic capabilities like adding columns and altering properties of existing ones.

The paper also mentions that when reading from tablets with a previous schema version, LittleTable will translate the rows to the latest table schema. So old data gets mapped to the updated schema transparently.

In summary, LittleTable does allow its table schema to be evolved to some degree, especially by appending new columns. But the full details and flexibility of schema changes are not discussed in depth. The focus seems to be more on just adding new data over time under the different query patterns.

## Management operations

### Tablet Management
As in-memory tablets fill up, LittleTable:
1. Closes them to writes 
2. Adds them to flush queue
3. Opens a new empty tablet

A background merge process combines disk tablets while maintaining time-period restrictions. This controls disk usage growth.

### Management operations
According to the details provided in the paper, here are the main administrative operations that LittleTable performs:

Background Operations (non-blocking):

- Tablet merging - Periodically merges adjacent on-disk tablets to control tablet growth. Runs in background thread.

- Expired data deletion - Removes rows that have passed their time-to-live (TTL) period. Background process.


Potentially Blocking Operations:

- Table creation/deletion - Clients can drop a whole table or recreate it with a new schema. Likely blocks during operation.

- Table schema changes:
    - Appending columns (background)
    - Increasing column precision (background) 
    - Altering time-to-live period (background)

- Flushing in-memory tablets - Necessary when memory limit reached. May briefly block writes.

- Enforcing primary key uniqueness - May perform disk query to check keys, briefly blocking writes.


Continuous Archival: 

- Asynchronous replication to warm spare servers using PostgreSQL's continuous archiving.


So in summary, the mission critical background data management operations like merging, expiration, and archival are done asynchronously without impacting reads or writes. Schema changes can mostly happen seamlessly as well. The potential brief blocking operations are schema changes that require rewriting, flushing memory buffers, and checking primary key conflicts.

### Merging tablets
According to the paper, tables are merged in LittleTable for two main reasons:

1. To limit the number of on-disk tablets that need to be accessed to satisfy a query. If there are too many tablets, a query would require excessive random I/O to open a cursor on each one.

2. To reclaim space taken up by expired rows. Since LittleTable ages out old data after a configurable time-to-live (TTL), a background process will periodically merge tablets to remove expired rows and rewrite the remaining valid rows to new tablets.

Specifically, the paper mentions two merging policies:

1. Adjacent Tablet Merging: LittleTable will merge the oldest tablet with any adjacent, newer tablets that are less than half its size. This merging process continues until no more eligible adjacent tablets remain. This keeps the total number of tablets logarithmic in the total number of rows.

2. Time Period Merging: Tablets are grouped into time periods - 4 hour periods for the past day, daily periods for the past week, and weekly periods further back. Tablets are only merged with other tablets from the same time period. This prevents queries from scanning an excessive number of rows outside their time range.

In summary, LittleTable merges tables primarily to limit the number of on-disk tablets both for query efficiency and expired data removal. Adjacent tablets are merged to control tablet count growth. And time period rules prevent merging tablets from different time ranges.


## That's all folks
LittleTable's log-structured architecture, two-dimensional data clustering, and flexible schema make it well-suited for storing high-resolution time-series data cost-effectively while providing great query performance on recent data.

In this article we saw how easy it is to create ML training pipelines on GCP with Vertex AI pipelines and leaveraging off-the-shelf components to create an AutoML training job.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
