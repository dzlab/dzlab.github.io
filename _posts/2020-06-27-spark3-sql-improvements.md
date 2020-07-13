---
layout: post
comments: true
title: Spark 3.0 Major Changes for Spark SQL
categories: bigdata
tags: [spark]
toc: true
#img_excerpt: assets/2019/20190321-cnn-building-blocks-1.png
---

Spark 3.0 was long waited (more than a year and half since the release of Spark 2.4), finally 3.0.0 was released early June 2020. This release brought a lot of new features and enchacements, check the release notes for a detailed list of new features - [link](https://spark.apache.org/releases/spark-release-3-0-0.html). The following highlights improvements that concerns Spark SQL.

### New EXPLAIN format
[SPARK-27395](https://issues.apache.org/jira/browse/SPARK-27395) reformats the query execution plans for better readability.

To show this new feautre in aciton, we will use Titanic dataset from Kaggle [link](https://www.kaggle.com/c/titanic).
```scala
val opts = Map("delimiter"->",", "header"->"true", "inferSchema"->"true")
val df = spark.read.options(opts).csv("titanic.csv")
df.createOrReplaceTempView("titanic")
```

The following is a simple query that we will use to try the query explainer.
```scala
val query = "SELECT Cabin, Embarked, Max(Fare) FROM titanic WHERE Age < 20 GROUP BY Cabin, Embarked HAVING max(Fare) > 10"
```

The old query plan looks like the following, as you can see it is very complex even for a relatively simple query.
```scala
scala> sql(s"EXPLAIN $query").show(false)
|== Physical Plan ==
*(2) Project [Cabin#645, Embarked#646, max(Fare)#764]
+- *(2) Filter (isnotnull(max(Fare#644)#767) AND (max(Fare#644)#767 > 10.0))
   +- *(2) HashAggregate(keys=[Cabin#645, Embarked#646], functions=[max(Fare#644)])
      +- Exchange hashpartitioning(Cabin#645, Embarked#646, 200), true, [id=#349]
         +- *(1) HashAggregate(keys=[Cabin#645, Embarked#646], functions=[partial_max(Fare#644)])
            +- *(1) Project [Fare#644, Cabin#645, Embarked#646]
               +- *(1) Filter (isnotnull(Age#640) AND (Age#640 < 20.0))
                  +- FileScan csv [Age#640,Fare#644,Cabin#645,Embarked#646] Batched: false, DataFilters: [isnotnull(Age#640), (Age#640 < 20.0)], Format: CSV, Location: InMemoryFileIndex[file:/Users/dzlab/Downloads/spark-3.0.0-bin-hadoop2.7/titanic.csv], PartitionFilters: [], PushedFilters: [IsNotNull(Age), LessThan(Age,20.0)], ReadSchema: struct<Age:double,Fare:double,Cabin:string,Embarked:string>

```
The new formatted output adds tons of information that makes understanding the query execution lot easier. The output plans is divided into two sections:
* A header section displays a tree of SQL operator and for each one a number is associated.
* A footer section lists for each operator more details: input, output, arguments, etc.

```scala
scala> sql(s"EXPLAIN FORMATTED $query").show(false)
|== Physical Plan ==
* Project (8)
+- * Filter (7)
   +- * HashAggregate (6)
      +- Exchange (5)
         +- * HashAggregate (4)
            +- * Project (3)
               +- * Filter (2)
                  +- Scan csv  (1)


(1) Scan csv 
Output [4]: [Age#640, Fare#644, Cabin#645, Embarked#646]
Batched: false
Location: InMemoryFileIndex [file:/Users/dzlab/Downloads/spark-3.0.0-bin-hadoop2.7/titanic.csv]
PushedFilters: [IsNotNull(Age), LessThan(Age,20.0)]
ReadSchema: struct<Age:double,Fare:double,Cabin:string,Embarked:string>

(2) Filter [codegen id : 1]
Input [4]: [Age#640, Fare#644, Cabin#645, Embarked#646]
Condition : (isnotnull(Age#640) AND (Age#640 < 20.0))

(3) Project [codegen id : 1]
Output [3]: [Fare#644, Cabin#645, Embarked#646]
Input [4]: [Age#640, Fare#644, Cabin#645, Embarked#646]

(4) HashAggregate [codegen id : 1]
Input [3]: [Fare#644, Cabin#645, Embarked#646]
Keys [2]: [Cabin#645, Embarked#646]
Functions [1]: [partial_max(Fare#644)]
Aggregate Attributes [1]: [max#787]
Results [3]: [Cabin#645, Embarked#646, max#788]

(5) Exchange
Input [3]: [Cabin#645, Embarked#646, max#788]
Arguments: hashpartitioning(Cabin#645, Embarked#646, 200), true, [id=#392]

(6) HashAggregate [codegen id : 2]
Input [3]: [Cabin#645, Embarked#646, max#788]
Keys [2]: [Cabin#645, Embarked#646]
Functions [1]: [max(Fare#644)]
Aggregate Attributes [1]: [max(Fare#644)#781]
Results [4]: [Cabin#645, Embarked#646, max(Fare#644)#781 AS max(Fare)#782, max(Fare#644)#781 AS max(Fare#644)#785]

(7) Filter [codegen id : 2]
Input [4]: [Cabin#645, Embarked#646, max(Fare)#782, max(Fare#644)#785]
Condition : (isnotnull(max(Fare#644)#785) AND (max(Fare#644)#785 > 10.0))

(8) Project [codegen id : 2]
Output [3]: [Cabin#645, Embarked#646, max(Fare)#782]
Input [4]: [Cabin#645, Embarked#646, max(Fare)#782, max(Fare#644)#785]
```

### All type of join hints
[SPARK-27225](https://issues.apache.org/jira/browse/SPARK-27225) Extend the existing BROADCAST join hint by implementing other join strategy hints corresponding to the rest of Spark's existing join strategies: shuffle-hash, sort-merge, cartesian-product. Broadcast-nested-loop will use BROADCAST hint as it does now.

## Dynamic optimizations
### Adaptive query execution
### Dynamic partitioning pruning

## Catalyst improvements
### Enhanced nested column pruning & pushdown
### Improved aggregation code generation

## Infrastructure updates
### New Scala and Java

https://www.slideshare.net/ishizaki/sql-performance-improvements-at-a-glance-in-apache-spark-30?qid=2e4e4b84-a924-4e2d-b992-4d5c8cbb25ea

https://medium.com/cloudzone/apache-spark-3-0-review-what-the-spark-is-all-about-998844e12b3c

https://mungingdata.com/spark-3/array-exists-forall-transform-aggregate-zip_with/


Prometheus: https://databricks.com/session_na20/native-support-of-prometheus-monitoring-in-apache-spark-3-0

https://spark.apache.org/releases/spark-release-3-0-0.html

### Shuffle
- https://issues.apache.org/jira/browse/SPARK-25299
🔊 Apache Spark Shuffle Metadata Tracking Design

✔️ This document explained on tracking the shuffle data that is stored in these external systems. This is a sub-topic under Remote Storage for Persisting Shuffle Data !

🔕 Shuffle primitive requires #apachespark executors to persist data to the local disk of the worker nodes. If executors crash, the external shuffle service can continue to serve the shuffle data that was written beyond the lifetime of the executor itself.

#dataengineering #bigdata #distributedsystems