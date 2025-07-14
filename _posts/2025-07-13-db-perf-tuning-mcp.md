---
layout: post
comments: true
title: PostgreSQL performance tuning with MCP and Claude
excerpt: Learn how to use MCP tools with Claude to tuning the query performance of PostgreSQL
categories: genai
tags: [ai,llm,db]
toc: true
img_excerpt:
mermaid: true
---

Is your web application grinding to a halt? Users complaining about slow page loads? Before you throw more hardware at the problem or implement complex caching layers, you should first try to reveal exactly what's slowing down your PostgreSQL database.

Meet [pg-extras-mcp](https://github.com/dzlab/snippets/tree/master/pg-extras-mcp) – a diagnostic tool inspired by [ruby-pg-extras](https://github.com/pawurb/ruby-pg-extras), it exposes a set of [well known troubleshooting SQL queries](https://github.com/dzlab/snippets/tree/master/pg-extras-mcp/queries) as a collection of Model Context Protocol (MCP) tools. Then, with the power of an LLM like [Claude](https://claude.ai/), even the non PostgreSQL optimization expert can turn the database's internal statistics into actionable insights, expose any bottleneck, wasteful indexes, and optimization opportunities.

In this hands-on guide, you'll learn:

- How to identify if the database needs more resources or just better tuning
- The secret to eliminating storage-wasting indexes that slow down writes
- Advanced techniques for optimizing queries and reducing lock contention
- Battle-tested strategies for managing database bloat and storage efficiency

## pg-extras-mcp
The [pg-extras-mcp](https://github.com/dzlab/snippets/tree/master/pg-extras-mcp) tool provides access to PostgreSQL's internal statistics through simple function calls. Each exposed method queries PostgreSQL's system tables to provide insights into database performance.

Below is the full list of available tools split into: performance, storage, indexing, connections, and maintenance aspects.

### Database Analysis & Monitoring
- **bloat** - Shows table and index bloat in your database ordered by most wasteful
- **cache_hit** - Displays index and table hit rate for cache performance
- **table_cache_hit** - Calculates your cache hit rate specifically for reading tables
- **index_cache_hit** - Calculates your cache hit rate specifically for reading indexes
- **buffercache_stats** - Calculates percentages of relations buffered in database shared buffer
- **buffercache_usage** - Shows how many blocks from which table are currently cached

### Table & Index Information
- **tables** - Lists all the tables in the database
- **table_size** - Shows size of tables (excluding indexes), descending by size
- **total_table_size** - Shows size of tables (including indexes), descending by size
- **table_indexes_size** - Shows total size of all indexes on each table, descending by size
- **indexes** - Lists all indexes with their corresponding tables and columns
- **index_size** - Shows the size of indexes, descending by size
- **total_index_size** - Shows total size of all indexes in MB
- **table_schema** - Displays table column names and types
- **table_foreign_keys** - Shows foreign key information for a specific table

### Index Performance & Usage
- **index_usage** - Shows index hit rate (effective databases are at 99% and up)
- **index_scans** - Shows number of scans performed on indexes
- **table_index_scans** - Shows count of index scans by table in descending order
- **unused_indexes** - Lists unused and almost unused indexes ordered by size relative to index scans
- **duplicate_indexes** - Finds multiple indexes with the same columns, opclass, expression and predicate
- **null_indexes** - Finds indexes with a high ratio of NULL values

### Query Performance
- **outliers** - Shows queries with longest execution time in aggregate
- **outliers_17** - Alternative version for PostgreSQL 17+ with longest execution time queries
- **outliers_legacy** - Legacy version of outliers query
- **calls** - Shows queries with highest frequency of execution
- **calls_17** - Alternative version for PostgreSQL 17+ with highest frequency queries
- **calls_legacy** - Legacy version of calls query
- **long_running_queries** - Lists all queries longer than threshold by descending duration

### Connection & Lock Management
- **connections** - Returns list of all active database connections
- **blocking** - Shows queries holding locks that other queries are waiting for
- **locks** - Shows queries with active exclusive locks
- **all_locks** - Shows queries with active locks (all types)
- **kill_pid** - Kills database connection by its PID
- **kill_all** - Kills all active database connections

### Database Maintenance
- **vacuum_stats** - Shows dead rows and whether automatic vacuum is expected to be triggered
- **seq_scans** - Shows count of sequential scans by table in descending order
- **records_rank** - Lists all tables and number of rows in each, ordered by row count descending

### Configuration & Extensions
- **db_settings** - Shows values of selected PostgreSQL settings
- **extensions** - Lists available and installed extensions
- **ssl_used** - Checks if SSL connection is being used
- **add_extensions** - Configures extensions necessary for other queries to work

### Statistics Management
- **pg_stat_statements_reset** - Resets statistics gathered by `pg_stat_statements` extension

---

_I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc)._
