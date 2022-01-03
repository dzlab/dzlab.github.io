---
layout: post
comments: true
title: Monitoring up and running with Docker Compose, Prometheus and Grafana
excerpt: Learn how to quickly setup a monitoring stack with Docker Compose, Prometheus and Grafana.
categories: monitoring
tags: [docker,prometheus,grafana]
toc: true
img_excerpt:
---

<img align="left" src="/assets/logos/icons8-docker.svg" width="240" />
<img align="left" src="/assets/logos/icons8-grafana.svg" width="240" />
<img align="center" src="/assets/logos/icons8-prometheus.svg" width="220" />
<br/>

Usually the monitoring setup for a cloud native application will be deployed on kubernetes with service discovery and high availability (e.g. using a kubernetes operator like [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)). To quickly prototype dashboards and experiment with different metric type options (e.g. histogram vs gauge) you may need a similar setup locally. This post explains how to setup locally a Prometheus/Alert Manager and Grafana monitoring stack with Docker Compose.

First, lets define a general component of the stack as follows:
- An Alert Manager container that exposes its UI at 9093 and read its configuration from `alertmanager.conf`
- A Prometheus container that exposes its UI at 9090 and read its configuration from `prometheus.yml` and its list of alert rules from `alert_rules.yml`
- A Grafana container that exposes its UI at 3000, with list of metrics sources defined in `grafana_datasources.yml` and configuration in `grafana_config.ini`

The following `docker-compose.yml` file summaries the configuration of all those components:

```yaml
## docker-compose.yml ##

version: '3'

volumes:
  prometheus_data: {}
  grafana_data: {}

services:

  alertmanager:
    container_name: alertmanager
    hostname: alertmanager
    image: prom/alertmanager
    volumes:
      - ./alertmanager.conf:/etc/alertmanager/alertmanager.conf
    command:
      - '--config.file=/etc/alertmanager/alertmanager.conf'
    ports:
      - 9093:9093

  prometheus:
    container_name: prometheus
    hostname: prometheus
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alert_rules.yml:/etc/prometheus/alert_rules.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
    links:
      - alertmanager:alertmanager
    ports:
      - 9090:9090

  grafana:
    container_name: grafana
    hostname: grafana
    image: grafana/grafana
    volumes:
      - ./grafana_datasources.yml:/etc/grafana/provisioning/datasources/all.yaml
      - ./grafana_config.ini:/etc/grafana/config.ini
      - grafana_data:/var/lib/grafana
    ports:
      - 3000:3000
```

Second, optionally define the alert manager configuration (see reference documentation - [link](https://prometheus.io/docs/alerting/latest/configuration/)). For local development you probably don't need to configure anything and can keep the file empty, unless you need to test alert been pushed to an external service by AlertManager. For instance, the following configuration defines how alerts will be sent to pager duty.

```yaml
## alertmanager.conf ##

global:
  resolve_timeout: 1m
  pagerduty_url: 'https://events.pagerduty.com/v2/enqueue'

route:
  receiver: 'pagerduty-notifications'

receivers:
- name: 'pagerduty-notifications'
  pagerduty_configs:
  - service_key: 0c1cc665a594419b6d215e81f4e38f7
    send_resolved: true
```

Third, optionally define prometheus alerts in `alert_rules.yml`. To define some alerts based on metrics in Prometheus, you can group then into a `alert_rules.yml` so you could validate those alerts are properly triggered in your local setup before configuring them in the production instance. For instance the following configration defines an alert on heap memory used vs max ratio when it crosses 80%

```yaml
## alert_rules.yml ##

groups:  
  - name: JVMMemory 
    rules:
      - alert: JVMMemoryThresholdCrossed
        # Condition for alerting
        expr: jvm_memory_committed_bytes{region="heap"}/jvm_memory_max_bytes{region="heap"} > 0.8
        # Annotation - additional informational labels to store more information
        annotations:
          title: 'Instance {{ $labels.instance }} has crossed 80% heap memory usage'
          description: '{{ $labels.instance }} of job {{ $labels.job }} has crossed 80% heap memory usage'
        # Labels - additional labels to be attached to the alert
        labels:
          severity: 'critical'
```

Forth, and most importantly define Prometheus configuration in `prometheus.yml` file. This will defines:
- the global settings like scrapping interval and rules evaluation interval
- the connection information to reach AlertManager and the rules to be evaluated
- the connection information to application metrics endpoint.

This is an example configration file:

```yaml
## prometheus.yml ##

# global settings
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

alerting:
  alertmanagers:
    - static_configs:
      - targets: ["alertmanager:9093"]

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  - /etc/prometheus/alert_rules.yml

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: 'vad-metrics'
    metrics_path: '/metrics'
    scrape_interval: 5s
    static_configs:
      - targets: ['docker.for.mac.host.internal:9091']
```

> Note: in this case, prometheus will connect to a metrics endpoing at 9091 running outside docker on the machine itself, hence the hostname `docker.for.mac.host.internal`.

Fifth, define grafana startup configuration. For instance, `grafana_config.ini` may look like this

```ini
## grafana_config.ini ##

[paths]
provisioning = /etc/grafana/provisioning

[server]
enable_gzip = true
```

Sixth, and most importantly define where the grafana service can find the prometheus service in a `grafana_datasources.yml`. In our case, Prometheus is running in the container named `prometheus` thus the file would look like this.

```yaml
## grafana_datasources.yml ##

apiVersion: 1

datasources:
  - name: 'prometheus'
    type: 'prometheus'
    access: 'proxy'
    url: 'http://prometheus:9090'
```

Finally, after defining all the configuration file as well as the docker compose file we can start the monitoring stack with `docker-compose up`

```
$ docker-compose up
Creating network "monitoring_default" with the default driver
Creating volume "monitoring_prometheus_data" with default driver
Creating volume "monitoring_grafana_data" with default driver
Creating grafana      ... done
Creating alertmanager ... done
Creating prometheus   ... done
Attaching to grafana, alertmanager, prometheus
alertmanager    | level=info ts=2022-01-03T21:52:24.751Z caller=main.go:225 msg="Starting Alertmanager" version="(version=0.23.0, branch=HEAD, revision=61046b17771a57cfd4c4a51be370ab930a4d7d54)"
prometheus      | level=info ts=2022-01-03T21:52:25.364Z caller=main.go:438 msg="Starting Prometheus" version="(version=2.30.3, branch=HEAD, revision=f29caccc42557f6a8ec30ea9b3c8c089391bd5df)"
grafana         | t=2022-01-03T21:52:26+0000 lvl=info msg="Live Push Gateway initialization" logger=live.push_http
grafana         | t=2022-01-03T21:52:26+0000 lvl=info msg="inserting datasource from configuration " logger=provisioning.datasources name=prometheus uid=
grafana         | t=2022-01-03T21:52:26+0000 lvl=info msg="HTTP Server Listen" logger=http.server address=[::]:3000 protocol=http subUrl= socket=
```

Once the containers are up and running, you can visit
- Grafana at http://localhost:3000/ (username/password is `admin`/`admin`)
- Prometheus at http://localhost:9090/
- AlertManager at http://localhost:9093/

To stop the monitoring stack run the following command
```
$ docker-compose down -v
```