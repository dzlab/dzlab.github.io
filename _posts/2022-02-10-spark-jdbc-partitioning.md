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

![spark read no partitioning]({{ "assets/2022/02/20220210-spark-read-no-partitioning.png" | absolute_url }}){: .center-image }


![spark read partitioning]({{ "assets/2022/02/20220210-spark-read-partitioning.png" | absolute_url }}){: .center-image }


https://developpaper.com/read-and-write-millions-of-data-of-spark-sql-to-mysql-in-batches/

https://jozef.io/r926-spark-jdbc-partitioning/

https://medium.com/@radek.strnad/tips-for-using-jdbc-in-apache-spark-sql-396ea7b2e3d3