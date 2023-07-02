---
layout: post
comments: true
title: Network observability with Elasticsearch on AWS
excerpt: On building a comprehensive Network observability platform with the Elastic stack
tags: [elasticsearch,network,aws]
toc: true
img_excerpt:
---

<img align="left" src="/assets/logos/elasticsearch.svg" width="120" />
<br/>

Network issues are very common source of trouble for micro-services but still are not easy to troubleshoot, especially in a cloud environment. For instance, you may have seen puzzling cases where a lot of log entries in one service contain `connection timeout` errors yet no indication of issues can be found in the logs of the remove service.

Cloud providers usually provide tools to help pinpoint the root cause of network issues. For instance on AWS, one can uses Athena to analyze VPC logs [see AWS solutions blog](https://aws.amazon.com/blogs/networking-and-content-delivery/analyze-vpc-flow-logs-with-point-and-click-amazon-athena-integration/). But unfortunately such a solution brings a lot of complexity (many components) and cost (i.e. budget and maintenance). In fact, it envovles too many steps:
- Deploying an AWS Glue database with partitioned tables,
- Setting up an Athena Workgroup using CloudFormation,
- Wrangling data with Athena using pseudo-SQL queries.
— Copying, pasting, and rewriting S3 bucket keys.
- In addition to the requirement of frequently repartition the data

To effeciently manage a production (or even a staging) environemnt with many services (business applications, core infrastructure systems, etc), requires setting up an observability and alerting platform. The main goals of such a platform is to reduce the amount of time spent on debugging network systems (firewalling, routing, etc.) and thus minimizing downtime by providing the ability to search massive amount of network traffic logs and issue alerts. Furthermore, it should help perform network analysis (e.g. post-mortems after incidents) by providing the ability to explore logs spanning any time period regardless of the size of the logs history.

The Elastic stack with its many components is the perfect candidate to build such an in-house platform. As it allows to
- Ingest real-time application logs with Logstash or Beats for network logs
- Store massive amount of logs with Elasticsearch's indices
- And search across logs spanning long time periods with Kibana

One would arg why not use an AWS managed log analysis solutions like CloudWatch to build such an observability platform instead of building one and having to manage it. But using CloudWatch is can be become very expensive. For instance, at the time of writing this article, it would cost $0.50 per GB for data ingestion (refere to [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/)) alone which can easily adds up as network logs are high-throughput log streams. But using Elasticsearch, would require using local file storage (EBS) to store data chunks and indexes with the possibility to archive this data on S3. Plus the search cabilities of Elasticsearch are quite efficient due to the indexing phase. To estimate the cost of running an Elasticsearch cluster on AWS refer to the [Elastic Pricing FAQ](https://www.elastic.co/pricing/faq).

## Ingesting VPC flow logs into Elasticsearch

The following diagram illustrates a high level solution on how to build a network observability platform with Elasticsearch on AWS.

![Network observability elasticsearch architecture]({{ "/assets/2023/03/2023-03-04-network-observability-elastic-architecture.svg" | absolute_url }})

Elasticsearch cluster can be deployed from AWS Marketplace while other AWS resources like the VPC Flow Logs, the S3 buckets, the Lambda function, and the SQS queues can be deployed with Terraform as follows:

First, create the different resources with Terraform as follows
```
# S3 bucket where log files will be uploaded
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-bucket"
}

# SQS queue for notifications when log files are uploaded
resource "aws_sqs_queue" "my_queue" {
  name = "my-queue"
}

# Lambda function for processing log files and ingesting them
resource "aws_lambda_function" "my_function" {
  name = "my-function"

  handler = "index.handler"
  runtime = "python3.8"

  code = {
    zip_file = "lambda_function.zip"
  }
}
```

Then, we need to make sure that VPC Flow logs are uploaded to a designated S3 bucket. For instance, using Terraform we can do the following:
```
resource "aws_flow_log" "vpc_flow_log_to_s3" {
    log_destination      = "S3_BUCKET_ARN"
    log_destination_type = "s3"
    traffic_type         = "ALL"
    vpc_id               = "VPC_ID"
}
```

When a new VPC Flow Log file is uploaded to the S3 bucket, we want to put an entry in SQS queue with information about the file such as the file name, the file size, and the file content.

Using Terraform, we can create such a notification rule by providing the source bucket to be notified when files are uploaded to it, and specifying the destination SQS queue where notifications will be sent. This is an example configuration:
```
resource "aws_s3_bucket_notification" "s3_to_sqs_notification" {
  bucket = "S3_BUCKET_ARN"
  event_types = ["s3:ObjectCreated:*"]
  sqs_queue = "S3_SQS_ARN"
}
```

Next, we need to create an event trigger for the Lambda function that will process log files and ingest them into Elasticsearch. The event trigger should be set to fire when a new entry is added to the SQS queue. In Terraform, we can do the following:

```
resource "aws_lambda_event_source_mapping" "my_event_source_mapping" {
  event_source_arn = "S3_SQS_ARN"
  function_name = "LAMBDA_FUNCTION_NAME"
}
```

Inside the lambda function, we need implement the logic to process log files and ingest them to Elasticsearch. The following snippet illustrates a very simplifed version:

```js
const AWS = require('aws-sdk');
const elasticsearch = require('elasticsearch');

exports.handler = async (event, context) => {
  const s3 = new AWS.S3();
  const es = new elasticsearch.Client({
    hosts: ['<ELASTICSEARCH_HOST>:<ELASTICSEARCH_PORT>'],
  });

  const bucket = event.bucket;
  const key = event.key;

  const file = await s3.getObject({
    Bucket: bucket,
    Key: key,
  }).promise();

  const data = file.Body.toString();

  const index = 'logs';
  const doc = {
    message: data,
  };

  await es.index({
    index: index,
    type: 'doc',
    id: key,
    document: doc,
  }).promise();
};
```

After everything is deployed, the VPC flow logs will be uploaded to S3 and then ingested into Elasticsearch. We can verify that the logs are being ingested by querying Elasticsearch. For example, you can use the following command to search for all logs that contain the word `"error"`:

```sh
curl -XGET 'http://<ELASTICSEARCH_HOST>:<ELASTICSEARCH_PORT>/logs/_search?q=error'
```

If the logs are being ingested, you should see a response that contains a list of documents that match the search criteria.


## That's all folks
I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
