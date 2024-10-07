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





## That's all folks
In this article, we saw how easy is it to build a new data Adapter for Apache Calcite in order to query random data systems with SQL.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
