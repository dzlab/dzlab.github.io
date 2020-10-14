---
layout: post
comments: true
title: Ingesting data into Elasticsearch using Alpakka
categories: ml
tags: [elasticsearch, akka]
toc: true
img_excerpt: assets/2020/10/20201013-elasticsearch-alpakka.svg
---

![elasticsearch-alpakka]({{ "assets/2020/10/20201013-elasticsearch-alpakka.svg" | absolute_url }}){: .center-image }


[Alpakka](https:/​/​doc.​akka.​io/​docs/​alpakka/​current/​index.​html) is a reactive enterprise integration library for JVM languages. It is based on [Reactive Streams](http://www.reactive-streams.org/) principles and implemented as a layer on top of Lightbend's [Akka](https:/​/​akka.​io/​) and [Akka Streams](https://doc.akka.io/docs/akka/current/stream/index.html) libraries.


In a Reactive streams terminology, we have two important components **Sources** (which are used to read data from different) and **Sinks** (which are used to write data into).
Alpakka supports Source and Sink for many data stores through tons of modules, including:
* Kafka
* Cassandra
* AWS S3
* MQTT
* File
* Simple Codecs
* CSV
* AWS SQS
* AMQP
* Elasticsearch

One would ask why to use Alpakka to write or read from Elasticsearch instead of using a more standard approach. Alpakka leverages the Akka Streams toolkit which provides low latency complex event processing streaming semantics all built on top of the highly concurrent Akka actor system. This gives Alpakka the ability to:

* Build back-pressure aware integrations: If a data store is under high load, it automatically reduces the throughput.
* Build Complex Event Processing (CEP) using a plethora of operators (map, flatMap, filter, groupBy, mapAsync, and so on)
* Have a modular approach as Sources and Sinks can be replaced to read and write to different data stores without massive code refactoring.
* Have a low memory footprint as data streams from the Source to the Sink.
* Be easily dockerized and deployed on a Kubernetes cluster for large scale ETL.

![elasticsearch-alpakka-scenario]({{ "assets/2020/10/20201013-elasticsearch-alpakka-scenario.svg" | absolute_url }}){: .center-image }

The rest of this article will illustrate how to ingest data from a CSV Source into an Elasticsearch Sink using Alpakka. Full example code can be found [here](https://github.com/dzlab/snippets/tree/master/elastic4s).


First, make sure elasticsearch server is up and running locally:
```sh
$ cd $ELASTICSEARCH_HOME
$ ./bin/elasticsearch
...
[2020-10-12T19:34:56,250][INFO ][o.e.n.Node               ] [unknown] initialized
[2020-10-12T19:34:56,250][INFO ][o.e.n.Node               ] [unknown] starting ...
[2020-10-12T19:34:56,368][INFO ][o.e.t.TransportService   ] [unknown] publish_address {127.0.0.1:9300}, bound_addresses {[::1]:9300}, {127.0.0.1:9300}
...
[2020-10-12T19:34:59,762][INFO ][o.e.c.c.CoordinationState] [unknown] cluster UUID set to [HHaTRovfTWef8WzfvXx-6w]
[2020-10-12T19:34:59,785][INFO ][o.e.c.s.ClusterApplierService] [unknown] master node changed {previous [], current [{unknown}{YNaScUqqT324sjwlmfdL6Q}{SIcw7UNSSeixnPPJuH_ESw}{127.0.0.1}{127.0.0.1:9300}{dilmrt}{ml.machine_memory=17179869184, xpack.installed=true, transform.node=true, ml.max_open_jobs=20}]}, term: 1, version: 1, reason: Publication{term=1, version=1}
[2020-10-12T19:34:59,825][INFO ][o.e.h.AbstractHttpServerTransport] [unknown] publish_address {127.0.0.1:9200}, bound_addresses {[::1]:9200}, {127.0.0.1:9200}
[2020-10-12T19:34:59,826][INFO ][o.e.n.Node               ] [unknown] started
```

Declare Alpakka as dependencies in your `buid.sbt`:
```scala
val alpakkaLibs = Seq(
  "com.lightbend.akka" %% "akka-stream-alpakka-csv" % alpakkaVersion,
  "com.lightbend.akka" %% "akka-stream-alpakka-elasticsearch" % alpakkaVersion,
  "com.typesafe.akka" %% "akka-stream" % akkaVersion
)
```

Initialize the Actor system
```scala
implicit val actorSystem = ActorSystem()
implicit val actorMaterializer = ActorMaterializer()
implicit val executor = actorSystem.dispatcher
```

Initialize an Elasticsearch Rest client to be used by Alpakka Elasticsearch Sink
```scala
implicit val client: RestClient = RestClient.builder(new HttpHost("0.0.0.0", 9200)).build()
```

Make sure data instances are in Json, so if you have a `case class` representing your data then create JSON serializers and deserializers using `spray.json` and the Scala macro `jsonFormatN` (with N being the number of fields). For instance:
```scala
case class Data(label: String, f1: Double, f2: Double, f3: Double, f4: Double)
import spray.json._
import DefaultJsonProtocol._
implicit val format: JsonFormat[Data] = jsonFormat5(Data)
```

Define the strategy for Back pressure and retries that Alpakka will use when initializing Elasticsearch Sink. For instance:
```scala
val sinkSettings = ElasticsearchWriteSettings()
  .withBufferSize(1000)
  .withVersionType("internal")
  .withRetryLogic(RetryAtFixedRate(maxRetries = 5, retryInterval = 1.second))
```
In the above settings example we use:
* `withBufferSize(size:Int)` : to set the number of messages to be used for a single bulk.
* `withVersionType(vType:String)`: to set the type of record versioning in Elasticsearch.
* `withRetryLogic(logic:RetryLogic)`: to set the retry policies. In this case we used the `RetryAtFixedRate` implementation that will allow 5 max retries at a fixed 1 second retry interval.


At last, create the actual pipeline that will read from a CSV Source, for every line, it will create a message and ingest it to a destination Elastisearch index throughout the Elasticsearch Sink. For instance:
```scala
val graph = Source.single(ByteString(Resource.getAsString("data.csv")))
  .via(CsvParsing.lineScanner())
  .drop(1) // remove header
  .map(values => WriteMessage.createIndexMessage[Data](
    Data(values(5).utf8String, values.head.utf8String.toDouble, values(1).utf8String.toDouble, values(2).utf8String.toDouble, values(3).utf8String.toDouble))
  )
  .via(ElasticsearchFlow.create[Data]("data-alpakka", "_doc", settings = sinkSettings))
  .runWith(Sink.ignore)
```

As the pipeline runs asynchronously, we may want (at least in this toy example) wait for the entire pipeline to finish before existing the program. We can using Scala `Await` for this as follows:
```scala
Await.result(graph, Duration.Inf)
```

In the previous pipeline, we used a function to transform the raw instances of our Data class into instances of `WriteMessage`. This is because Elasticsearch Sink or Flow accepts only objects with type `WriteMessage[T, PT]`, where `T` is the type of the message and `PT` is a possible `PassThrough` type. We would use the later for instance in case we wanted to pass a Kafka offset and commit it after the Elasticsearch writes a response.

To create objects of type `WriteMessage` we would need to use of its factory methods:
* `createIndexMessage[T](source: T)`: to create an index action
* `createIndexMessage[T](id: String, source: T)`: to create an index action with given id
* `createCreateMessage[T](id: String, source: T)`: to build a create action
* `createUpdateMessage[T](id: String, source: T)`: to create an update action
* `createUpsertMessage[T](id: String, source: T)`: to create an upsert action (it tries to update the document, or create a new one if it does not exist)
* `createDeleteMessage[T](id: String)`: to create a delete action


After we created the WriteMessages, we can create a Sink with `ElasticsearchFlow.create` to write the records in Elasticsearch with the following parameters:
* `indexName:String` the name of the index to be used.
* `typeName:String` the mapping name (usually _doc in Elasticsearch 7.x).
* `settings: ElasticsearchWriteSettings` (optional) the setting parameters for write.


After running the pipeline we can check the created documents
```sh
$ curl http://localhost:9200/data-alpakka/_search?pretty
{
  "took" : 4,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 150,
      "relation" : "eq"
    },
    "max_score" : 1.0,
    "hits" : [
      {
        "_index" : "data-alpakka",
        "_type" : "_doc",
        "_id" : "USEjIHUBTTUbuCko7OOM",
        "_score" : 1.0,
        "_source" : {
          "f1" : 1.0,
          "f2" : 5.1,
          "f3" : 3.5,
          "f4" : 1.4,
          "label" : "xyz"
        }
      },
      ...
    ]
  }
}
```


Happy searching!