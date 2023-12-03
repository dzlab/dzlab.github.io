---
layout: post
comments: true
title: Network observability with Elasticsearch on AWS - Part I
excerpt: On building a comprehensive Network observability platform with the Elastic stack
tags: [elasticsearch,network,aws]
toc: true
img_excerpt:
---

<img align="center" src="/assets/logos/elasticsearch.svg" width="120" />
<br/>
<br/>

Network issues are very common source of trouble for micro-services but still are not easy to troubleshoot, especially in a cloud environment. For instance, you may have seen puzzling cases where a lot of log entries in one service contain `connection timeout` errors yet no indication of issues can be found in the logs of the remove service.

Cloud providers usually provide tools to help pinpoint the root cause of network issues. For instance on AWS, one can uses Athena to analyze VPC logs [see AWS solutions blog](https://aws.amazon.com/blogs/networking-and-content-delivery/analyze-vpc-flow-logs-with-point-and-click-amazon-athena-integration/). But unfortunately such a solution brings a lot of complexity (many components) and cost (i.e. budget and maintenance). In fact, it envovles too many steps:
- Deploying an AWS Glue database with partitioned tables,
- Setting up an Athena Workgroup using CloudFormation,
- Wrangling data with Athena using pseudo-SQL queries.
— Copying, pasting, and rewriting S3 bucket keys.
- In addition to the requirement of frequently repartition the data

## Ingesting VPC flow logs into Elasticsearch

To effeciently manage a production (or even a staging) environemnt with many services (business applications, core infrastructure systems, etc), requires setting up an observability and alerting platform. The main goals of such a platform is to reduce the amount of time spent on debugging network systems (firewalling, routing, etc.) and thus minimizing downtime by providing the ability to search massive amount of network traffic logs and issue alerts. Furthermore, it should help perform network analysis (e.g. post-mortems after incidents) by providing the ability to explore logs spanning any time period regardless of the size of the logs history.

The Elastic stack with its many components is the perfect candidate to build such an in-house platform. As it allows to
- Ingest real-time application logs with Logstash or Beats for network logs
- Store massive amount of logs with Elasticsearch's indices
- And search across logs spanning long time periods with Kibana

One would arg why not use an AWS managed log analysis solutions like CloudWatch to build such an observability platform instead of building one and having to manage it. But using CloudWatch is can be become very expensive. For instance, at the time of writing this article, it would cost $0.50 per GB for data ingestion (refere to [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/)) alone which can easily adds up as network logs are high-throughput log streams. But using Elasticsearch, would require using local file storage (EBS) to store data chunks and indexes with the possibility to archive this data on S3. Plus the search cabilities of Elasticsearch are quite efficient due to the indexing phase. To estimate the cost of running an Elasticsearch cluster on AWS refer to the [Elastic Pricing FAQ](https://www.elastic.co/pricing/faq).

## Overview of the architecture

The following diagram illustrates a high level solution on how to build a network observability platform with Elasticsearch on AWS.

![Network observability elasticsearch architecture]({{ "/assets/2023/03/2023-03-04-network-observability-elastic-architecture.svg" | absolute_url }})

Logs from VPC Flow logs are batched into files and then uploaded to a S3 bucket. Every time, a file is uploaded an new entry is appended to SQS queue with information about the file. This triggers an Lambda function that will process and ingest the logs into Elasticsearch. Once the logs reach Elasticsearch, they can be retrived though Kibana or used to populate a custom dashboard.

In addition to VPC Flow logs, other sources of logs can be integrated into this architecture to debug other type of issues (e.g. IAM related errors) for instance CloudTrail logs and Cloudfront logs in batch mode.

In some cases, errors are encountered inside the Lambda function during the processing of log files. In such cases, the lambda function can forward the original S3 event to a Dead-Letter Queue (DLQ), then sending the messages back to the main queue to be reprocessed again later.


In Part II, we will deep dive into setting up sush observability platform on AWS.

## That's all folks
I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
