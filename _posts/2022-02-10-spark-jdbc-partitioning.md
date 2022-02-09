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