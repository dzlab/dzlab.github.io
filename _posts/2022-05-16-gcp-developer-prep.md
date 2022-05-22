---
layout: post
comments: true
title: GCP Developer Certification Preparation Guide
excerpt: Tips and resources to get ready for passing Google Developer Certification.
categories: certification
tags: [gcp,data,cloud,certification]
toc: true
img_excerpt:
---

<center><img alt="Professional Developer Certification" src='https://badges.images.credential.net/1548352102758.png' width='300' height='300'></center>


I recently passed Google Professional Developer Certification, during the preparation I went throught lot resources about the exam. I also used this [book](https://www.amazon.com/Google-Cloud-Certified-Professional-Developer/dp/1800560990) which is a good read and covers most of the exam topics. It is very good starting point for the preparation if you have little knowledge on Google Cloud services.

> Keep in mind that Google update its services very often, thus any source of information other than the official documentation may become out dated.

The exam is relatively at the same difficulty level of the Data engineer certification exam:
- It is recommended to have at least 3 years of industry experience with at least 1 years using GCP.
- The format of the exam is Multiple choice quesitons, to be finished within 2h.
- You can take the exam in person at a test center.
- One difference, is the exam has 60 questions instead of the typical 50.

The exman focuses on the following areas:
- Storage: block and persistent disks
- Databases: sql and nosql databases, warehousing
- Compute: AppEngine, Compute, kubernetes, functions
- Networking: VPC, data-centers to GCP connections
- DevOps: CI, CD, deployment strategies
- Security: permissions, roles, groups, service accounts, etc.

I could not find a comprehensive resource that covers all aspect of the exam when I started preparing. I had to go over a lot of Google Cloud products page and general Machine Learning resources and at no point I felt ready as both topics are huge. Here I will try to provide a summary of the resources I did found helpful for passing the exam.

## Storage
You need to know the different storage classes (see [link](https://cloud.google.com/storage/docs/storage-classes)) for your workload. Which one to use to save costs without sacrificing performance by storing data across different storage classes.

The following table summaries the different storage classes and how they compare to each other.

|Class | Storage Cost | Access Cost | Access Frequency | Description |
| - | - | - | - | - |
|Standard | High | Low | Access data frequently | Hot or Frequently accessed data: websites, streaming videos, and mobile apps.|
|Nearline | Low | High | Access data only once a month | Data stored for at least 30 days, including data backup and long-tail multimedia content.|
|Coldline | Very low | Very High | Access data only once a year. | Data stored for at least 90 days, including disaster recovery.|
|Archive | Lowest | Highest | | Data stored for at least 365 days, including regulatory archives.|
| Multi-Regional Storage| High | High | Access data frequently | Equivalent to Standard Storage, except it can only be used for objects stored in multi-regions or dual-regions. |

Other important topcis related to Cloud storage
- Retention Policy to control for how long objects are persist (e.g. for regulation) - [link](https://cloud.google.com/storage/docs/bucket-lock)
- Signed URLs and how to share objects - [link](https://cloud.google.com/storage/docs/access-control/signed-urls)

For general best practices related to Google Storage check this [link](https://cloud.google.com/storage/docs/best-practices).

## Databases
You need to know the different databases offered in GCP and which one to use for a given use case.

### SQL
Cloud SQL service provides hosted relational Databases (Postgresql, MySql, SQL Server), and multi-region SQL Database (Spanner). You need to know:

- What Cloud SQL is and the use cases when to use it - [link](https://cloud.google.com/sql/docs/)
- How to securely access Cloud SQL from an application and when to use Cloud SQL Proxy - [link](https://cloud.google.com/sql/docs/mysql/external-connection-methods)
- Schema design best practices for Cloud Spanner - [link](https://cloud.google.com/spanner/docs/schema-design)
- How to perform migrations from on-prem to GCP - [link](https://cloud.google.com/solutions/migrating-postgresql-to-gcp)
- How to import data into and export it out of Cloud SQL - [link](https://cloud.google.com/sql/docs/postgres/import-export/importing)



### NoSQL
GCP offers a variety of NoSQL databases, you need to know the difference between those services and when to use each one.
#### BigTable
Bigtable is a hosted NoSQL database alternative to Cassandra and HBase. It stores data in a unique way which makes it suitable for low latency access and time-series data (e.g. Financial market data).
- Read the service overview to gain minimum understanding - [link](https://cloud.google.com/bigtable/docs/overview)
- You need to know how to design row keys - [link](https://cloud.google.com/bigtable/docs/schema-design#types_of_row_keys)
- You need to know what hotspotting is and how to avoid it - [link](https://cloud.google.com/bigtable/docs/schema-design-time-series#ensure_that_your_row_key_avoids_hotspotting)
- You need to how to investigate performance issues, for exampling use Key Visualizer - [link](https://cloud.google.com/bigtable/docs/keyvis-overview)
- Read the schema design best practices for BigTable - [link](https://cloud.google.com/bigtable/docs/schema-design)

#### Firestore
Easily develop rich applications using a fully managed, scalable, and serverless document database.

Firestore in Native mode is the next generation of Datastore. It is recommended for storing user-session information and is a natural choice for this test.

- Know how Firestore can be used for mobile/web apps - [link](https://cloud.google.com/architecture/building-scalable-web-apps-with-cloud-datastore)
- Know how Firestore can be used offline and how data is synced when client comes back online - [link](https://cloud.google.com/firestore/docs/manage-data/enable-offline)
- Read the best Practices for using Datastore - [link](https://cloud.google.com/datastore/docs/best-practices)
- Read the best Practices for using Firestore - [link](https://cloud.google.com/firestore/docs/best-practices)

#### Memorystore
Memorystore is an in-memory database suitable as cache for fast data access - [link](https://cloud.google.com/memorystore).
- Read the overview of the Redis flavor - [link](https://cloud.google.com/memorystore/docs/redis/redis-overview)
- Read the overview of the Memcached flavor - [link](https://cloud.google.com/memorystore/docs/memcached/memcached-overview)

### Data warehouse
BigQuery is a hosted, serverless data warehouse. It has limited update/delete capabilities for inserted rows but is very performant for analytic workloads.

- Know how to load data from Firestore - [link](https://cloud.google.com/bigquery/docs/loading-data-cloud-firestore)
- How to migrate an on-premises data warehouse to BigQuery - [link](https://cloud.google.com/blog/topics/developers-practitioners/how-migrate-premises-data-warehouse-bigquery-google-cloud)


#### Syntax
You need to know basic SQL syntax to use BigQuery, for instance the different types of `JOIN` operations - [link](https://cloud.google.com/bigquery/docs/reference/standard-sql/query-syntax#join_types)

| Join | Description | Example |
| - | - | - |
|[INNER] JOIN | An INNER JOIN, or simply JOIN, effectively calculates the Cartesian product of the two from_items and discards all rows that do not meet the join condition.| `FROM A INNER JOIN B ON A.w = B.y` |
| CROSS JOIN | returns the Cartesian product of the two from_items. In other words, it combines each row from the first from_item with each row from the second from_item.| `FROM A CROSS JOIN B` |
| FULL [OUTER] JOIN | A FULL OUTER JOIN (or simply FULL JOIN) returns all fields for all rows in both from_items that meet the join condition.| `FROM A FULL OUTER JOIN B ON A.w = B.y`|
| LEFT [OUTER] JOIN | A LEFT OUTER JOIN (or simply LEFT JOIN) for two from_items always retains all rows of the left from_item in the JOIN operation, even if no rows in the right from_item satisfy the join predicate. | `FROM A LEFT OUTER JOIN B ON A.w = B.y` |
| RIGHT [OUTER] JOIN | A RIGHT OUTER JOIN (or simply RIGHT JOIN) is similar and symmetric to that of LEFT OUTER JOIN. | `FROM A RIGHT OUTER JOIN B ON A.w = B.y` |

## Compute
Choosing a Google Cloud compute option - [link](https://cloud.google.com/blog/topics/developers-practitioners/where-should-i-run-my-stuff-choosing-google-cloud-compute-option)

## Certification SWAG
After passing the exam, you can choose one of the official certification swags:

![developer-certification-swags]({{ "assets/2022/05/20220520-gc-dev-certif-swags.png" | absolute_url }}){: .center-image }

## That's all folks
Check my the following preparation tips for passing other Google certifications:
- Data Engineer certification - [link](https://dzlab.github.io/certification/2021/12/04/gcp-data-engineer-prep/) and
- Machine Learning Engineer certification - [link](https://dzlab.github.io/certification/2022/01/08/gcp-ml-engineer-prep/).

Feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc)