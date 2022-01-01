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

`docker-compose.yml`

```yaml
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