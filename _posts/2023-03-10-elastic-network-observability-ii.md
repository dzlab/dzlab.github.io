---
layout: post
comments: true
title: Network observability with Elasticsearch on AWS - Part II
excerpt: On building a comprehensive Network observability platform with the Elastic stack
tags: [elasticsearch,network,aws]
toc: true
img_excerpt:
---

![Network observability elasticsearch architecture]({{ "/assets/2023/03/2023-03-04-network-observability-elastic-architecture.svg" | absolute_url }})

In Part I, we discussed the need for setting up a centeralized log management platform to debug network issues. In this second part, we will deep dive into deploying this platform on AWS using Terraform.

## Deploying with Terraform
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

## Searching the logs
Elasticsearch provides very powerful search capbilities to search and analyze large amounts of data. It has a simple and an extensive search syntax. For instance to retrieve from the logs all `REJECTED` network traffic with a source IP from the 10.0.0.0/8 CIDR range and a destination IP, we can use the following query:

```json
{
  "query": {
    "bool": {
      "must": [
        {
          "match": {
            "type": "REJECTED"
          }
        },
        {
          "range": {
            "source_ip": {
              "gte": "10.0.0.0",
              "lte": "10.255.255.255"
            }
          }
        },
        {
          "match": {
            "destination_ip": {
              "exists": true
            }
          }
        }
      ]
    }
  }
}
```

The above query will first match all documents that have a type of "REJECTED". It will then match all documents that have a source IP address that falls within the 10.0.0.0/8 CIDR range. And finally, it will match all documents that have a destination IP address that exists.


We can simplify our search query using the [Kibana Query Language](https://www.elastic.co/guide/en/kibana/current/kuery-query.html). Which is a powerful way to search and filter data in Elasticsearch. It is a query language that allows you to specify the criteria that you want to use to search for documents. Kibana search syntax uses a variety of keywords to specify the criteria for your search, like the `match` keyword to match specific values. It also allows the use of logical operators (e.g. `AND`, `OR`) to combine multiple criteria.

Back to our search query, we can simplify it using Kibana query syntax as follows:

```
source.ip:10.0.0.0/8 AND event.action:rejected AND destination.ip:*
```

This query will return all rejected network traffic with a source IP from the 10.0.0.0/8 CIDR range and a destination IP.

## That's all folks
I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
