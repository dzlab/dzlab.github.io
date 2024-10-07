---
layout: post
comments: true
title: SQL anything with Apache Calcite
excerpt: How to build a custom data adapter for Apache Calcite
categories: database
tags: [calcite,rest]
toc: true
img_excerpt: assets/logos/Apache_Calcite_Logo.svg
---

<img align="center" src="/assets/logos/Apache_Calcite_Logo.svg" />
<br/>


[Apache Calcite](https://calcite.apache.org/docs/howto.html) is a data management framework that provides many of the components that a typical database like Postgres would have. Mainly, Apache Calcite provides SQL parsing and validation, as well as query optimiser but does not provide implementation for data storage or data processing. It also supports custom functionalities such as new SQL syntax, functions, or storage plugins via a [plugable adapters API](https://calcite.apache.org/docs/adapter.html) that makes it easy to integrate with third-party data sources.

Apache Calcite is used as a SQL interface by a lot of Data storage systems, especially NoSQL systems: [Cassandra](https://calcite.apache.org/docs/cassandra_adapter.html), [Elasticsearch](https://calcite.apache.org/docs/elasticsearch_adapter.html), [MongoDB](https://calcite.apache.org/javadocAggregate/org/apache/calcite/adapter/mongodb/package-summary.html), etc. For more examples check the [Community page](http://calcite.apache.org/community/#talks).

In the article, we will see how to implement a custom Adapter for Apache Calcite to query a REST API with SQL. We will wrap the [';--have i been pwned?](https://haveibeenpwned.com/api/v2) REST API to query account breach data with SQL. [The complete source code can be found on GitHub](https://github.com/dzlab/snippets/tree/master/calcite-adapter).


## Calcite Architecture
The following diagram highlights the major components of Apache Calcite and how information circulate among them.

When a user submits a SQL query via JDBC driver, Calcite first parse and validate the query syntactically against the SQL flavor and the data catalog (tables, fields, etc). The output of this step is a relational algebra expression (or Logical Plan) that matches exactly the input query but is defined with [Relational Operators](https://en.wikipedia.org/wiki/Relational_algebra).

The next step in Calcite pipeline is to transform the logical plan using a set of rules to generate plan candidates, e.g. rewriting the expression to join tables in a different order, or to use different operators. The query optimizer then estimates the execution cost (e.g. using statistics from storage system) of each candidate plan and selects the plan with lowest cost.

Calcite does not store its own data or metadata, but instead allows external data and metadata to be accessed by means of plugable Adapters. So the final step in Calcite pipeline is to push the transformation of the plan into a Physical plan using any specific rules provided by the adapter where each operator can be executed by the storage system.

![Apache Calcite Architecture](/assets/2024/07/20240706-calcite-architecture.svg)

## Calcite Adapter
As highlited in the previous section, Calcite relies on the external Adapters to provide Catalog metadata. A Catalog refers to a logical grouping of **schemas**, **tables**, **views**, and other database objects. It serves as a namespace for organizing and managing metadata, such as schema definitions, table structures, and function/operator definitions.

Technically a Catalog is a logical abstraction that allows external data and metadata to be accessed through plug-ins and provides Calcite with a way to:

- Resolve fully qualified schema names to schema objects (e.g., tables, views).
- Retrieve information about schema objects, such as column types and constraints.
- Provide a list of all functions and operators defined in the catalog.
- Support user-defined types (UDTs) and their associated metadata.

This decoupling enables Calcite to work with various data sources and metadata stores, such as relational databases, NoSQL databases, and file systems.

Some key concepts related to catalogs in Apache Calcite that an adapter need to implement:

**Schema**

A Schema A logical grouping of tables, views, and other database objects. A schema can also contains nested schemas.

An adapter needs to implement the following interface for decalring a Schema in Calcite:

```java
public interface Schema {

    Table getTable(String name);
    Set<String> getTableNames();
    Schema getSubSchema(String name);
    Set<String> getSubSchemaNames();
}
```

As you can see, the implementation need to provide the list of tables and nested schemas.

**Table**

A Table in Calcite represents a single dataset, and can have one or many fields which are defined by `RelDataType`. The following interface need to be implemented by the adapter:

```java
public interface Table {

    RelDataType getRowType(RelDataTypeFactory typeFactory);
    Statistic getStatistic();
    Schema.TableType getJdbcTableType();
}
```

Most importantly, the adapter should provide a way to get the rows for the table, as when as the type information for each field. Optionally, an adapter can provide Statistics about the table (e.g. rows count) that can be used by the Query optimizer.

## Data

[HaveIBeenPwned](https://haveibeenpwned.com/) is a free resource for one to quickly assess if they are at risk due to one of their an online account having been **pwned** (i.e. compromised) by a data breach.
A **data breach** is an incident where a hacker illegally obtains data (e.g. personal account) from a system then released them to the public domain. HaveIBeenPwned collects, aggregates publicly leaked **data breaches**, and makes them searchable.

HaveIBeenPwned provides an easy to use REST API to list data about breaches as well as the list of pwned accounts (email addresses and usernames).

The base URL for this service when using version 2 of the API is as follows:

```
https://haveibeenpwned.com/api/v2/{service}/{parameter}
```

In our case, and for simplicity, we will only use the `/breaches` endpoint that returns information about public data breaches. The full URL for this service is [https://haveibeenpwned.com/api/v2/breaches](), it returns a list of JSON objects that look like the following example:

```json
  {
    "Name": "Zurich",
    "Title": "Zurich",
    "Domain": "zurich.co.jp",
    "BreachDate": "2023-01-08",
    "AddedDate": "2023-01-22T22:30:56Z",
    "ModifiedDate": "2023-01-22T22:30:56Z",
    "PwnCount": 756737,
    "Description": "In January 2023, <a href=\"https://therecord.media/millions-of-aflac-zurich-insurance-customers-in-japan-have-data-leaked-after-breach/\" target=\"_blank\" rel=\"noopener\">the Japanese arm of Zurich insurance suffered a data breach that exposed 2.6M customer records with over 756k unique email addresses</a>. The data was subsequently posted to a popular hacking forum and also included names, genders, dates of birth and details of insured vehicles. The data was provided to HIBP by a source who requested it be attributed to &quot;IntelBroker&quot;.",
    "LogoPath": "https://haveibeenpwned.com/Content/Images/PwnedLogos/Zurich.png",
    "DataClasses": [
      "Dates of birth",
      "Email addresses",
      "Genders",
      "Names",
      "Vehicle details"
    ],
    "IsVerified": true,
    "IsFabricated": false,
    "IsSensitive": false,
    "IsRetired": false,
    "IsSpamList": false,
    "IsMalware": false,
    "IsSubscriptionFree": false
  }
```

## That's all folks
In this article, we saw how easy is it to build a new data Adapter for Apache Calcite in order to query random data systems with SQL.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
