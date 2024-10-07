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


[Apache Calcite](https://calcite.apache.org/docs/howto.html) is a data management framework that provides many of the components that a typical database like Postgres would have. Mainly, Apache Calcite provides SQL parsing and validation, as well as query optimiser but does not provide implementation for data storage or data processing. It also provides a [plugable adapters API](https://calcite.apache.org/docs/adapter.html) to integrate with third-party data sources.

Apache Calcite is used as a SQL interface by a lot of Data storage systems, especially NoSQL systems: [Cassandra](https://calcite.apache.org/docs/cassandra_adapter.html), [Elasticsearch](https://calcite.apache.org/docs/elasticsearch_adapter.html), [MongoDB](https://calcite.apache.org/javadocAggregate/org/apache/calcite/adapter/mongodb/package-summary.html), etc. For more examples check the [Community page](http://calcite.apache.org/community/#talks).

In the article, we will see how to implement a custom Adapter for Apache Calcite to query a REST API with SQL. We will wrap the [';--have i been pwned?](https://haveibeenpwned.com/api/v2) REST API to query account breach data with SQL. [The complete source code can be found on GitHub](https://github.com/dzlab/snippets/tree/master/calcite-adapter).

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

## Calcite Adapter

![Apache Calcite Architecture](/assets/2024/07/20240706-calcite-architecture.svg)

A schema is collection of schema and tables
A schema can be arbitrary nested

```java
public interface Schema {

    Table getTable(String name);
    Set<String> getTableNames();
    Schema getSubSchema(String name);
    Set<String> getSubSchemaNames();
}
```

A Table represents a single dataset
Fields are defined by a `RelDataType`

```java
public interface Table {

    RelDataType getRowType(RelDataTypeFactory typeFactory);
    Statistic getStatistic();
    Schema.TableType getJdbcTableType();
}
```

## That's all folks
In this article, we saw how easy is it to build a new data Adapter for Apache Calcite in order to query random data systems with SQL.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
