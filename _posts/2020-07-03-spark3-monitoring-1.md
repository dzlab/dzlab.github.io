---
layout: post
comments: true
title: Spark 3.0 Monitoring with Prometheus
categories: bigdata
tags: [spark, monitoring]
toc: true
#img_excerpt: assets/2020/20200703-spark-prometheus.png
img_alt: Spark with Prometheus
---

![spark-prometheus]({{ "/assets/2020/20200703-spark-prometheus.png" | absolute_url }}){: .center-image }

## Monitoring prior to 3.0
Prior to Apache Spark 3.0, there were different approaches to expose metrics to Prometheus:

1- Using Spark's JmxSink and Prometheus's [JMXExporter](https://github.com/prometheus/jmx_exporter) (see [Monitoring Apache Spark on Kubernetes with Prometheus and Grafana](https://dzlab.github.io/data/2020/06/08/monitoring-spark-prometheus/))
* Enable Spark’s built-in JmxSink with `$SPARK_HOMEconf/metrics.properties`
* Deploy Prometheus' JMXExporter library and its conﬁg ﬁle
* Expose JMXExporter port, 9091, to Prometheus Add `-javaagent` option to the target (master/worker/executor/driver)
```
./spark-submit \
  ... \
  --conf spark.driver.extraJavaOptions=-javaagent:$SPARK_HOME/jars/jmx_prometheus_javaagent.jar=9091:$SPARK_HOME/conf/prometheus-config.yml \
  ...
```

2- Using Spark's GraphiteSink and Prometheus's [GraphiteExporter](https://github.com/prometheus/graphite_exporter)
* Set up Graphite server Enable Spark’s built-in
* Graphite Sink with several conﬁgurations
* Enable Prometheus’GraphiteExporter at Graphite

3- Using custom sinks and Prometheus's [Pushgateway](https://github.com/prometheus/pushgateway)
* Set up Pushgateway server
* Develop a custom sink (or use 3rd party libs) with Prometheus dependency
* Deploy the sink libraries and its conﬁguration ﬁle to the cluster

## Monitoring in 3.0
Apache Spark 3.0 introduced the following resources to expose metrics:
* `PrometheusServlet` [SPARK-29032](https://issues.apache.org/jira/browse/SPARK-29032) which makes the Master/Worker/Driver nodes expose metrics in a Prometheus format (in addition to JSON) at the existing ports, i.e. 8080/8081/4040.
* `PrometheusResource` [SPARK-29064](https://issues.apache.org/jira/browse/SPARK-29064)/[SPARK-29400](https://issues.apache.org/jira/browse/SPARK-29400) which export metrics of all executors at the driver. Enabled by `spark.ui.prometheus.enabled` (default: `false`)

Those features are more convinent than the agent approach that requires a port to be open (which may not be possible). The following tables summaries the new exposed endpoints for each node:

||Port| Prometheus Endpoint | JSON Endpoint |
|:--:|
|Driver| 4040| /metrics/prometheus/| /metrics/json/|
|Driver| 4040| /metrics/executors/prometheus/| /api/v1/applications/{id}/executors/|
|Worker| 8081| /metrics/prometheus/| /metrics/json/|
|Master| 8080| /metrics/master/prometheus/| /metrics/master/json/|
|Master| 8080| /metrics/applications/prometheus/| /metrics/applications/json/|


Copy `$SPARK_HOME/conf/metrics.properties.template` into `$SPARK_HOME/conf/metrics.properties` and add/uncomment the following lines (they should at the end of the template file):
```
*.sink.prometheusServlet.class=org.apache.spark.metrics.sink.PrometheusServlet
*.sink.prometheusServlet.path=/metrics/prometheus
master.sink.prometheusServlet.path=/metrics/master/prometheus
applications.sink.prometheusServlet.path=/metrics/applications/prometheus
```

For testing, start a Spark cluster as follows:
```bash
$ sbin/start-master.sh
$ sbin/start-slave.sh spark://`hostname`:7077
$ bin/spark-shell --master spark://`hostname`:7077
```
Note: to enable exector metrics we need to enable `spark.ui.prometheus.enabled`
```bash
$ bin/spark-shell --master spark://`hostname`:7077 \
    --conf spark.ui.prometheus.enabled=true \
    --conf spark.executor.processTreeMetrics.enabled=true
```

### Master metrics
Now we can query metrics of the Master node in JSON or in Prometheus compatible format:
```bash
$ curl -s http://localhost:8080/metrics/master/json/ | jq
{
  "version": "4.0.0",
  "gauges": {
    "master.aliveWorkers": {
      "value": 1
    },
    "master.apps": {
      "value": 1
    },
    ...
  }
}
$ curl -s http://localhost:8080/metrics/master/prometheus/ | head
metrics_master_aliveWorkers_Number{type="gauges"} 1
metrics_master_aliveWorkers_Value{type="gauges"} 1
metrics_master_apps_Number{type="gauges"} 1
metrics_master_apps_Value{type="gauges"} 1
```

### Worker metrics
The metrics of the Worker node in JSON or in Prometheus compatible format:
```bash
$ curl -s http://localhost:8081/metrics/json/ | jq
{
  "version": "4.0.0",
  "gauges": {
    "worker.coresFree": {
      "value": 0
    },
    ...
  }
}
$ curl -s http://localhost:8081/metrics/prometheus/ | head
metrics_worker_coresFree_Number{type="gauges"} 0
metrics_worker_coresFree_Value{type="gauges"} 0
metrics_worker_coresUsed_Number{type="gauges"} 8
metrics_worker_coresUsed_Value{type="gauges"} 8
```

### Driver metrics
And the metrics of the Driver in JSON or in Prometheus format as follows:
```bash
$ curl -s http://localhost:4040/metrics/json/ | jq
{
  "version": "4.0.0",
  "gauges": {
    "local-1593797764926.driver.BlockManager.disk.diskSpaceUsed_MB": {
      "value": 0
    },
    ...
  }
}
$ curl -s http://localhost:4040/metrics/prometheus/ | head
metrics_local_1593797764926_driver_BlockManager_disk_diskSpaceUsed_MB_Number{type="gauges"} 0
metrics_local_1593797764926_driver_BlockManager_disk_diskSpaceUsed_MB_Value{type="gauges"} 0
metrics_local_1593797764926_driver_BlockManager_memory_maxMem_MB_Number{type="gauges"} 366
metrics_local_1593797764926_driver_BlockManager_memory_maxMem_MB_Value{type="gauges"} 366
```

### Executors metrics
The Executors metrics in Prometheus format can be accessed as follows:
```bash
$ curl -s http://localhost:4040/metrics/executors/prometheus | head
spark_info{version="3.0.0", revision="3fdfce3120f307147244e5eaf46d61419a723d50"} 1.0
metrics_executor_rddBlocks{application_id="app-20200703115147-0001", application_name="Spark shell", executor_id="driver"} 0
metrics_executor_memoryUsed_bytes{application_id="app-20200703115147-0001", application_name="Spark shell", executor_id="driver"} 0
metrics_executor_diskUsed_bytes{application_id="app-20200703115147-0001", application_name="Spark shell", executor_id="driver"} 0
```
The Executors metrics in JSON format can be accessed as follows (an application ID need to be provided):
```bash
$ curl -s http://localhost:4040/api/v1/applications/app-20200703115147-0001/executors | jq
[
  {
    "id": "driver",
    "hostPort": "10.0.0.242:57429",
    "isActive": true,
    ...
  }
]
```