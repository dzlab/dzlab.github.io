---
layout: post
comments: true
title: Network observability with Elasticsearch on GCP
excerpt: On building a comprehensive Network observability platform with the Elastic stack on GCP
tags: [elasticsearch,network,gcp]
toc: true
img_excerpt:
---

![GCP Network observability elasticsearch architecture]({{ "/assets/2023/04/2023-04-17-network-observability-elastic-architecture-gcp.svg" | absolute_url }})

On a previous [Article](https://dzlab.github.io/2023/03/04/elastic-network-observability-i/), we discussed the need for setting up a centeralized log management platform to debug network issues.


In the remaining of this article, we will briefly describe the architecture and then deep dive into deploying it on GCP using Cloud Deployment Manager.

## Overview of the architecture

The above diagram illustrates a high level solution on how to build a network observability platform with Elasticsearch on GCP.

Logs from VPC Flow logs are batched into files and then uploaded to a Cloud Storage bucket. Every time, a file is uploaded an new entry is appended to PubSub queue with information about the file. This triggers a Cloud Function that will process and ingest the logs into Elasticsearch. Once the logs reach Elasticsearch, they can be retrived though Kibana or used to populate a custom dashboard.

In addition to VPC Flow logs, other sources of logs can be integrated into this architecture to debug other type of issues (e.g. permission errors) for instance Cloud Audit Logs and Cloud CDN logs in batch mode.

In some cases, errors are encountered inside the Cloud Function during the processing of log files. In such cases, the Cloud Function can forward the original Cloud Storage event to a [Dead-Letter Queue (DLQ)](https://cloud.google.com/pubsub/docs/handling-failures), which will cause the messages with failures to be sent back to the main queue for reprocessing.

## Deploying with Cloud Deployment Manager
Elasticsearch cluster can be deployed from GCP Marketplace while other GCP resources like the VPC Flow Logs, the Cloud Storage buckets, the Cloud Function, and the PubSub queues can be deployed with Cloud Deployment Manager as follows:

First, configure the different resources as follows 
```yaml
resources:
# Cloud Storage bucket where log files will be uploaded
- name: logs-bucket
  type: storage.v1.bucket
  properties:
    name: logs-bucket
    location: us-central1
    storageClass: STANDARD

# PubSub queue for notifications when log files are uploaded
- name: logs-upload-topic
  type: pubsub.v1.topic
  properties:
    name: logs-upload-topic

# Cloud Function for processing log files and ingesting them
- name: logs-processing-function
  type: cloudfunctions.v1.function
  properties:
    name: logs-processing-function
    runtime: nodejs14
    trigger_http: true
    source_archive_bucket: my-bucket
    source_archive_object: my-function.zip
```

Then, we need to make sure that VPC Flow logs are uploaded to a designated Cloud Storage bucket. For instance, using Cloud Deployment Manager we can do the following:
```yaml
resources:
- name: my-flow-log
  type: compute.v1.flow_log
  properties:
    name: my-flow-log-name
    target_bucket: logs-bucket
    filter:
      source_ranges:
      - 10.0.0.0/8
```

When a new VPC Flow Log file is uploaded to the Cloud Storage bucket, we want to put an entry in PubSub queue with information about the file such as the file name, the file size, and the file content.

Using `gsutil`, we can create such a notification rule by providing the source bucket to be notified when files are uploaded to it, and specifying the destination PubSub queue where notifications will be sent. This is an example configuration:
```shell
gsutil notification create -t logs-upload-topic -f json -e OBJECT_FINALIZE gs://logs-bucket
```

Next, we need to create an event trigger for the Cloud Function that will process log files and ingest them into Elasticsearch. The event trigger should be set to fire when a new entry is added to the PubSub queue. In Cloud Deployment Manager, we can define a subscription as follows:

```yaml
- name: logs-subscription
  type: pubsub.v1.subscription
  properties:
    name: logs-subscription
    topic: logs-upload-topic
    topic_path: projects/my-project/topics/logs-upload-topic
    push_config:
      push_endpoint: https://us-central1-functions.cloudfunctions.net/logs-processing-function
```

Save the content from all the previous snippets into `resources.yaml` the create them with
```shell
gcloud deployment-manager deployments create logs-deployment --config resources.yaml
```

Inside the Cloud Function, we need implement the logic to process log files and ingest them to Elasticsearch. The following snippet illustrates a very simplifed version:

```js
// Import the Cloud Storage and Elasticsearch libraries
const {Storage} = require('@google-cloud/storage');
const elasticsearch = require('elasticsearch');

exports.handler = async (event, context) => {
  // Create an Elasticsearch client
  const es = new elasticsearch.Client({
    host: 'elasticsearch.example.com',
    port: 9200,
  });

  // Get the file name from the event
  const fileName = event.name;

  // Get the file contents
  const file = await Storage.bucket(event.bucket).file(fileName).read();

  const data = file.Body.toString();

  const index = 'logs';
  const doc = {
    message: data,
  };

  // Index the file contents into Elasticsearch
  await es.index({
    index: index,
    type: 'doc',
    id: key,
    document: doc,
  }).promise();

  // Return a success message
  return {
    message: `File ${fileName} ingested into Elasticsearch`,
  };
};
```

After everything is deployed, the VPC flow logs will be uploaded to Cloud Storage and then ingested into Elasticsearch. We can verify that the logs are being ingested by querying Elasticsearch. For example, you can use the following command to search for all logs that contain the word `"error"`:

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
