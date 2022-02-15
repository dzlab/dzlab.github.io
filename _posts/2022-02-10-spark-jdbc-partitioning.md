---
layout: post
comments: true
title: Distributed database access with Spark and JDBC
excerpt: Tips on how to perform distributed database access and partitioning with Spark and JDBC.
categories: spark
tags: [spark,jdbc,partitioning]
toc: true
img_excerpt:
---


<img align="center" src="/assets/logos/Apache_Spark_logo.svg" height="240" />
<br/>


By default, when using a JDBC driver (e.g. Postgresql JDBC driver) to read data from a database into Spark only one partition will be used.

So if you load your table as follows, then Spark will load the entire table `test_table` into one partition

```scala
val df = spark.read
  .format("jdbc")
  .option("url", "jdbc:postgresql://localhost:5432/testdb")
  .option("user", "username")
  .option("password", "password")
  .option("driver", "org.postgresql.Driver")
  .option("dbtable", "test_table")
  .load()
```

You can confirm this by checking the Spark UI and you will notice that the load job had only one task as you can see in the following screenshot.

![spark read no partitioning]({{ "assets/2022/02/20220210-spark-read-no-partitioning.png" | absolute_url }}){: .center-image }

Luckily, Spark provides few parameters that can be used to control how the table will be partitioned and how many tasks Spark will create to read the entire table.

You can check all the options Spark provide for while using JDBC drivers in the documentation page - [link](https://spark.apache.org/docs/latest/sql-data-sources-jdbc.html). The options specific to partitioning are as follows:

|Option| Description|
|------|------------|
|partitionColumn|The column used for partitioning, it has to be numeric or date or timestamp column.|
|lowerBound|The minimum value in the partition column|
|upperBound|The maximum value in the partition column|
|numPartitions|The maximum number of partitions that can be used for parallel processing in table reading and writing. This also determines the maximum number of concurrent JDBC connections.|


> Note if the parition column is numeric then the values of `lowerBound` and `upperBound` has to be covertable to long or spark will through a `NumberFormatException`.

Now, when using those options the logic to read a table with Spark become something like this

```scala
val df = spark.read
  .format("jdbc")
  .option("url", "jdbc:postgresql://localhost:5432/testdb")
  .option("user", "username")
  .option("password", "password")
  .option("driver", "org.postgresql.Driver")
  .option("dbtable", "test_table")
  .option("partitionColumn", "test_column")
  .option("numPartitions", "10")
  .option("lowerBound", "0")
  .option("upperBound", "100")
  .load()
```

As you can imagine this approach will provide much more scalability then the earlier read option. You can confirm this by looking in the Spark UI and see that spark created `numPartitions` partitions and that each one of them has more or less `(upperBound - lowerBound) / numPartitions` rows. The following screenshot is a screenshot that shows how spark partitioned the red job.

![spark read partitioning]({{ "assets/2022/02/20220210-spark-read-partitioning.png" | absolute_url }}){: .center-image }


https://developpaper.com/read-and-write-millions-of-data-of-spark-sql-to-mysql-in-batches/

https://jozef.io/r926-spark-jdbc-partitioning/

https://medium.com/@radek.strnad/tips-for-using-jdbc-in-apache-spark-sql-396ea7b2e3d3