---
layout: post
comments: true
title: Pinterest's Wide Column Database in Python with RocksDB
excerpt: Building a simplified version of Pinterest's a Wide Column Database in Python with RocksDB
categories: database
tags: [python,rocksdb]
toc: true
img_excerpt:
---


In a recent article on [Pinterest Engineering Blog](https://medium.com/pinterest-engineering/building-pinterests-new-wide-column-database-using-rocksdb-f5277ee4e3d2), they desribed in details how they implemented in C++ a RocksDB-based distributed wide column database called **Rockstorewidecolumn**. While their system tackles petabytes and millions of requests per second with a distributed architecture, the core concepts of mapping a wide column data model onto a key-value store like RocksDB are fascinating.

This article explore how to implement a simpler, single-instance version of Pinterest's **Rockstorewidecolumn** in Python using the power and efficiency of RocksDB.


### What's a Wide Column Database, Anyway?

Think beyond traditional relational tables with fixed schemas. A wide column database offers:

*   **Rows:** Each identified by a unique `row_key`.
*   **Flexible Columns:** Each row can have a different set and number of columns. No predefined schema for all rows!
*   **Columnar Data:** Data is organized by columns within a row.
*   **Versioned Cells:** Often, values within a column can have multiple versions, typically timestamped.

This model is great for use cases like user profiles where users have varying attributes which can be available for some users and not for others, time-series data, or, as Pinterest showed, storing user event sequences.

### From Wide Columns to Simple Keys & Values

RocksDB is an incredibly fast embedded key-value store. However, It doesn't inherently understand "rows," "columns," or "versions." It just knows keys and values, and both of which are byte strings. Our main task is to cleverly design a **key structure** that lets us represent our wide column model.

From Pinterest's article, the Data Model Mapping (or **Logical View**) from Wide Columns to Key-Value looks like this

* **Dataset:** A collection of data for a use case (like a table).
* **Row:** Identified by a `row_key` (e.g., `user123`), contains items.
* **Item:** A `column_name` identifying a specific attribute within a row (e.g., `email`, `last_login_event`) with a list of versioned cells.
* **Cell:** A `timestamp` when this specific piece of data was recorded (e.g., milliseconds since epoch) and a `column_value` (the actual data).

To store a specific cell (a value for a given dataset, row, column, and time), we can simply concatenate these elements into a single RocksDB key and use a separator like the null byte `\x00`. The choice of the good separator is crutial as so what we don't confuse it with characters from the other attributes. This **Storage View** is visually explained with the following diagram.

```
+----------------------+-----------------+-------------------+-----------------+-----------------------+-----------------+-----------------------------------------+
| dataset_name_bytes   | KEY_SEPARATOR   | row_key_bytes     | KEY_SEPARATOR   | column_name_bytes     | KEY_SEPARATOR   | timestamp_bytes                         |
+----------------------+-----------------+-------------------+-----------------+-----------------------+-----------------+-----------------------------------------+
| (String as UTF-8)    | (Null Byte `\0`)| (String as UTF-8) | (Null Byte `\0`)| (String as UTF-8)     | (Null Byte `\0`)| (8-byte uint64, Big-Endian, Inverted)   |
+----------------------+-----------------+-------------------+-----------------+-----------------------+-----------------+-----------------------------------------+
```

One other thing to consider in the implementation is the versioning, and the ability to retrieve the latest versions of a column first.

For this, we can use a Timestamp trick that leverages the fact that RocksDB sorts keys lexicographically in ascending order. In fact, we can get a descending order for timestamps as follows:
* Use integer timestamps (e.g., milliseconds since epoch).
* Store `MAX_POSSIBLE_TIMESTAMP - actual_timestamp`.
* Pack this inverted timestamp as a fixed-length, big-endian byte string (e.g., using Python's `struct.pack('>Q', inverted_timestamp)` for an 8-byte unsigned integer).

This way, newer (smaller inverted) timestamps will sort before older ones.

Here is a complete Python snippet that demostrates how a Key is constructed:

```python
import struct
SEPARATOR = b"\x00"
dataset = b"user_profile"
row_key = b"user123"
column_name = b"email"
timestamp_ms = 1678886400000
MAX_UINT64 = 2**64 - 1
inverted_ts_bytes = struct.pack('>Q', MAX_UINT64 - timestamp_ms)
# The RocksDB key might look like
dataset + SEPARATOR + row_key + SEPARATOR + column_name + SEPARATOR + inverted_ts_bytes
```

Which results in a Key that looks like this:

```python
b'user_profile\x00user123\x00email\x00\xff\xff\xfey\x1a\x92\x8f\xff'
```

### Python Implementation

The full implementation of this Datastore can be found at this [GitHub KVWC project](https://github.com/dzlab/vibecoding/tree/main/kvwc), specifically in the [WideColumnDB](https://github.com/dzlab/vibecoding/blob/main/kvwc/wide_column_db.py) class.

Here are some key points from this implementation:

* **`_encode_key` / `_decode_key`:** facilitate translating our logical model to and from RocksDB's byte strings.
* **`put_row`:** Takes a list of items for a row. Each item can optionally specify a timestamp. If not, the current server time is used. All writes for a single `put_row` call are wrapped in a `rocksdb.WriteBatch` for atomicity at the row-key level for that call.
* **`get_row`:** the most complex method
  * It uses RocksDB's iterators and `seek()` operations.
  * To get all columns for a row, it seeks to `row_key_bytes + SEPARATOR`.
  * To get specific columns, it can either iterate and filter or seek to `row_key_bytes + SEPARATOR + column_name_bytes + SEPARATOR`.
  * It collects up to `num_versions` for each requested column, respecting the (optional) time range.
* **`delete_row`:** Also uses iterators to find all keys matching the criteria (entire row, specific columns, or even specific versions) and deletes them using a `WriteBatch`.

### Unlocking Wide Column Features

With the chosen key structure in our implementation, several wide column features become quite natural:

* **Versioned Values:** Automatically handled by including the timestamp in the key. Each update (even an "overwrite" of a conceptual column) with a new timestamp creates a new, distinct entry in RocksDB.
* **Time Range Queries:** The `get_row` method can filter versions based on `start_timestamp` and `end_timestamp` by examining the decoded timestamp from the key.
* **Out-of-Order Updates:** Clients can provide their own timestamps for data, allowing for backfills or event-time recording.
* **TTL (Time-to-Live):**
  * **Read-time enforcement:** When reading, check `key_timestamp + configured_ttl < current_timestamp`. If expired, don't return it.
  * **Physical deletion:** This is trickier for a simple implementation. RocksDB's compactions will eventually remove deleted data. A more advanced system might use RocksDB's compaction filters or a background process to scan and delete expired keys.

### What's Next?

The Trade-offs made in our Python implementation, makes it the datastore surprisingly useful for smaller-scale applications:

* **Single Instance:** It's not distributed, so no built-in replication, sharding, or high availability like Pinterest's Rockstorewidecolumn.
* **Basic Compaction:** Relies on RocksDB's default compaction unless you delve into advanced configurations or custom filters for TTL.
* **Pagination:** The `get_row` example above doesn't include pagination for very wide rows (many columns). This would require returning a "continuation token" (e.g., the last key part processed) for the client to pass in the next request.

Here are few things to consider if we were to expand this implementation:

* **Dataset/Table Management:** Consider using RocksDB's "Column Families" for better logical separation of different datasets (tables) within a single DB instance.
* **Advanced TTL:** Implement custom compaction filters or background jobs for efficient TTL enforcement.
* **Robust Pagination:** Add proper marker-based pagination to `get_row`.
* **Serialization:** Use a more robust serialization format than plain strings for values (e.g., JSON, MessagePack, Protobuf).


## That's all folks
This article walkthrough the implementation of a simplified version of Pinterest's Rockstorewidecolumn. We demonstrated that by carefully designing a key structure, we can map complex data models onto a high-performance key-value store like RocksDB.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
