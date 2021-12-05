---
layout: post
comments: true
title: GCP Data Engineer Certification Preparation Guide
excerpt: Tips and topics to get ready for passing Google Data Engineer Certification.
categories: certification
tags: [gcp,data,certification]
toc: true
img_excerpt:
---

<center><img alt="Professional Data Engineer Certification" src='https://badges.images.credential.net/1521043927706.png' width='400' height='400'></center>

I recently passed Google Professional Data Engineer Certification, during the preparation I went throught lot resources about Google Cloud. I also read this [book](https://www.oreilly.com/library/view/official-google-cloud/9781119618430/) but as Google update its services very often lot of the information in the book become out dated. The book is still a good read if you have little knowledge on Google Cloud services but make sure to also read the official documentation.

In this article, I compile the different resources I found most usefull/accurate during the preparation for the exam which can be useful to someone preparing for the exam. The exam itself is not very tough, although most of the questions are ambiguous and hence you need to be well prepared. You can learn more about the certification in the official page - [link](https://cloud.google.com/certification/data-engineer).


## Storage
Data Engineer role is all about data, hence the focus on storage technologies Google Cloud provides.

### BigQuery
BigQuery takes big chunk of the exam, lot questions are around how to design you table, optimize performance, migrated data into bigquery and how to use other Google cloud resources along with BigQuery.

**Overview**

- Moving BigQuery data between locations - [link](https://cloud.google.com/bigquery/docs/locations#moving-data)
- Partitioning tables. Based on what are they partitioned — ingestion time, timestamp, date. How are they named? How are they then accessed in queries? Using `_PARTITIONTIME`. - [link](https://cloud.google.com/bigquery/docs/partitioned-tables)
- How to cluster parititioned tables - [link](https://cloud.google.com/bigquery/docs/clustered-tables)
- User defined functions in BigQuery - [link](https://cloud.google.com/bigquery/docs/reference/standard-sql/user-defined-functions)
- Geospatial data analytics in BigQuery - [link](https://cloud.google.com/bigquery/docs/gis-intro)
- Accessing historical data using time travel - [link](https://cloud.google.com/bigquery/docs/time-travel)
- How to manage BigQuery flat-rate slots within a project - [link](https://cloud.google.com/blog/products/data-analytics/how-to-manage-bigquery-flat-rate-slots-within-a-project)
- SQL `MERGE` examples - [link](https://cloud.google.com/bigquery/docs/reference/standard-sql/dml-syntax#merge_statement)
- Bigquery. Know what a federated table is. While you are at it, learn also about clustered tables. - [link](https://cloud.google.com/bigquery/external-data-sources)
- BigQuery + GCS. Know how to link tables between GCS and BigQuery as permanent tables and temporary tables. - [link](https://cloud.google.com/bigquery/external-data-cloud-storage)
- BigQuery query plan. BigQuery allows you to see the query plan and execution profile for queries that you run. Know the phases, difference between average and max time, why there can be skew in the plan, and how to optimize for it. - [link](https://cloud.google.com/bigquery/query-plan-explanation)
- table date range for bq. Accessing tables with dates and partitioned tables with functions like `TABLE_DATE_RANGE`, `_TABLE_SUFFIX`, `TABLE_QUERY`.  - [link](https://stackoverflow.com/questions/22641894/bigquery-wildcard-using-table-date-range)
- Syntax for wildcards in big query names. And in legacy SQL? - [link](https://cloud.google.com/bigquery/docs/querying-wildcard-tables)

**Pseudo columns**
- `_TABLE_SUFFIX` contains the values matched by the table wildcard
```sql
#standardSQL
SELECT max, ROUND((max-32)*5/9,1) celsius, mo, da, year
FROM `bigquery-public-data.noaa_gsod.gsod194*`
WHERE max != 9999.9 AND ( _TABLE_SUFFIX = '0' OR _TABLE_SUFFIX = '4' )
ORDER BY max DESC
```

**Security**
- Basic roles for datasets - [link](https://cloud.google.com/bigquery/docs/access-control-basic-roles#dataset-basic-roles)
- Access at Table level - [link](https://cloud.google.com/blog/products/data-analytics/introducing-table-level-access-controls-in-bigquery)

**Data Transfer**

- BigQuery Data Transfer Service - [link](https://cloud.google.com/bigquery/transfer/)

**BigQuery ML**

- Overview - [link](https://cloud.google.com/bigquery-ml/docs/bigqueryml-web-ui-start)
- Data transformations with BigQuery ML - [link](https://cloud.google.com/blog/products/data-analytics/simplified-data-transformations-for-machine-learning-in-bigquery)

### Cloud Spanner

- Transaction support in Cloud Spanner - [link](https://cloud.google.com/spanner/docs/transactions#introduction)
- Schema design best practices - [link](https://cloud.google.com/spanner/docs/schema-design)
- Secondary index for cloud spanner. How indexes are created for you and how you can create secondary indexes. - [link](https://cloud.google.com/spanner/docs/secondary-indexes)

### Cloud Bigtable

- Understand architecture of bigtable - [link](https://cloud.google.com/bigtable/docs/overview)
- key reasons for high performance and ways to optimize - [link](https://cloud.google.com/bigtable/docs/performance)
- Know Key Visualiser - [link](https://cloud.google.com/bigtable/docs/keyvis-overview)
- Know when to scale BigTable - [link](https://cloud.google.com/bigtable/docs/scaling)
- Know performant key/schema design: row key scheme. What are the recommended ways for creating the row key? How do you avoid hotspotting? Should you use timestamp, and where? - [link](https://cloud.google.com/bigtable/docs/schema-design)
- Scaling up BigTable - [link](https://cloud.google.com/bigtable/docs/modifying-instance)
- If you need to double your reads for a prolonged period, what can you do to guarantee the same read latency?
- Dev to Prod cluster promotion
- HDD to SSD data migration


### Cloud Datastore

- How to use multiple indexes for datastore. Default indexes. Syntax for creating custom, composite indexes. - [link](https://cloud.google.com/datastore/docs/concepts/indexes)
- Export and import entities - [link](https://cloud.google.com/datastore/docs/export-import-entities)

### Pub/Sub

- Migrate from Kafka to PubSub - [link](https://cloud.google.com/blog/products/gcp/apache-kafka-for-gcp-users-connectors-for-pubsub-dataflow-and-bigquery)
- Know potential reasons for PubSub ingesting applications being busier than initially planned
- What PubSub metrics are available in Stackdriver and how to debug producers/consumers - [link](https://cloud.google.com/pubsub/docs/monitoring)
- Ordering messages - [link](https://cloud.google.com/pubsub/docs/ordering)
- Dealing with duplicate messages - [link](https://cloud.google.com/pubsub/docs/pull#dupes)
- Monitoring - [link](https://cloud.google.com/pubsub/docs/monitoring)
- At-Least-Once delivery  - [link](https://cloud.google.com/pubsub/docs/subscriber#at-least-once-delivery)
- Replay - [link](https://cloud.google.com/pubsub/docs/replay-overview)

### Data migrations

- Know when to use **Data Transfer Appliance**. Hint - slow network, huge dataset, no in-between refreshes. - [link](https://cloud.google.com/transfer-appliance/)
- When to use **Transfer Service** and what are its limitations. - [link](https://cloud.google.com/storage-transfer/docs/)
- Know the cost of storage and availability for various products: BigQuery, BigTable, Cloud SQL, GCS to be able to find the cheapest product for a set of availability/durability criteria.
- How **Dedicated Interconnect** impacts your data transfer decisions? - [link](https://cloud.google.com/interconnect/docs/concepts/dedicated-overview)
- How to **continuously sync** data between on-prem and GCP - [link](https://cloud.google.com/storage/docs/gsutil/commands/rsync)


## Processing
Data processing also takes big part of the exam, good knowledge of Dataflow/Beam operators may be required, and less for Dataproc/Hadoop/Spark.

### Cloud Dataflow
- Understand Apache Beam building blocks - Pipeline, PCollection, PTransform, ParDO - [link](https://beam.apache.org/documentation/programming-guide/)
- Know Side Inputs - [link](https://beam.apache.org/documentation/programming-guide/#side-inputs)
- Exactly once processing of PubSub messages - [link](https://cloud.google.com/blog/products/gcp/after-lambda-exactly-once-processing-in-cloud-dataflow-part-3-sources-and-sinks)
- Handling invalid inputs - [link](https://cloud.google.com/blog/products/gcp/handling-invalid-inputs-in-dataflow)
- Templates https://cloud.google.com/dataflow/docs/guides/templates/overview
- Dataflow developer mode. https://cloud.google.com/dataflow/docs/concepts/access-control


### Cloud Dataproc

- Preemptible workers - [link](https://cloud.google.com/dataproc/docs/concepts/compute/preemptible-vms)
- Scaling clusters - [link](https://cloud.google.com/dataproc/docs/concepts/configuring-clusters/scaling-clusters)
- Cloud Storage connector: usage of gcs instead of existing file system. It is a best practice to use Google Cloud Storage instead of using HDFS. You can destroy the compute nodes after data crunching and save cost on them.
- https://cloud.google.com/dataproc/docs/concepts/connectors/cloud-storage
- Dataproc: how to control scaling? Configure autoscaling?
https://cloud.google.com/dataproc/docs/concepts/configuring-clusters/autoscaling


## Machine Learning
There was few ML questions, but AI platform (now called vertext) may save you from surprises.

### ML Concepts
- feature crosses. Learn what these are and what issues it solves. - [link](https://developers.google.com/machine-learning/crash-course/feature-crosses/video-lecture)
- Go through the Coursera course on machine learning. - [link](https://www.coursera.org/learn/serverless-machine-learning-gcp/home/welcome)
- Dealing with overfitting. - [link](https://developers.google.com/machine-learning/crash-course/generalization/peril-of-overfitting)
- Regularization. What does it mean to increase or decrease regularization? - [link](https://www.coursera.org/lecture/deep-neural-network/why-regularization-reduces-overfitting-T6OJj)

### Cloud AutoML

- AutoML Vision Beginner's guide - [link](https://cloud.google.com/automl/docs/)

### Cloud Data Loss Prevention (DLP)

- Supported cryptographic methods in Cloud DLP (only read this section) - [link](https://cloud.google.com/dlp/docs/pseudonymization#supported-methods)

### Kubeflow
- Kubeflow - [link](https://www.kubeflow.org/docs/about/kubeflow/)

### Edge TPU

- Edge TPU - [link](https://cloud.google.com/edge-tpu)

## Cloud services
The remaining of the exam can touch more or less the following services, you need to at least read the overview of each one of the following services:

### Cloud Composer

- Overview - [link](https://cloud.google.com/composer/docs/concepts/overview)

### Data Catalog

- Overview - [link](https://cloud.google.com/data-catalog/docs/concepts/overview)


### Cloud Dataprep

- Overview - [link](https://cloud.google.com/dataprep/docs/quickstarts/quickstart-dataprep)
- Dataprep: jobs. How are Dataprep jobs created and run? What permissions do you need? A term I saw was that this is a more ‘casual’ way of data cleaning. As Dataproc/Dataflow requires programming knowledge - [link](https://cloud.google.com/dataprep/docs/html/Jobs-Page_57344842)

### Data Studio
- DataStudio: visualisation. What are the causes of stale data? And how do you get the latest? What caching options do you need to set?
- BigQuery+DataStudio — caching/pre-fetch cache. Learn how you connect DataStudio to storage solutions. Learn the difference between default caching (which cannot be disabled) and pre-fetch caching (which can be disabled). What is the difference between doing that with Viewer credentials and Owner credentials. - [link](https://support.google.com/datastudio/answer/7020039?hl=en)

### IAM
- How to allow cross team data access to BigQuery and GCS in a large organisation
- Key Management Service. Using KMS with non-GCP products. Note that there is a default key management where Google manages all the keys, then there is a customer managed encryption keys, and also a customer supplied encryption keys. - [link](https://cloud.google.com/kms/docs/)

### Other topics
- Know how to backup, migrate Datastore - [link](https://cloud.google.com/datastore/docs/schedule-export)
- Avro file format. This is a compressed format that bigquery/dataflow can work with it directly. - [link](https://cloud.google.com/bigquery/docs/loading-data-cloud-storage-avro)
- gsutil rsync usage - [link](https://cloud.google.com/storage/docs/gsutil/commands/rsync)
- logging data export - [link](https://cloud.google.com/logging/docs/export/aggregated_sinks)
