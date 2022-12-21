---
layout: post
comments: true
title: Get started with Packetbeat for network monitoring
excerpt: Learn how to setup packetbeat and start monitoring network traffic with ELK
tags: [elasticsearch,network]
toc: true
img_excerpt:
---

<img align="left" src="/assets/logos/elasticsearch.svg" width="120" />
<img align="left" src="/assets/logos/kibana.svg" width="100" />
<img align="center" src="/assets/logos/elastic-beats-logo-vector.svg width="100" />
<br/>

Packetbeat is a real-time network packet sniffer/analyzer which can be combined with Elasticsearch and Kibana to provide a powerfull network monitoring solution. Packetbeat captures network traffic from local devices and decodes a varity of application layer protocols (e.g. HTTP, MySQL, Redis). It is also capable of correlating the requests with their responses. Technically, it is based on the `libbeat` framework and integrates naturally with Elastic stack.

In this article we will see how to setup Packetbeat and get started with network monitoring.

## Setup

### Elasticsearch and Kibana
Before starting we need to setup Elasticsearch and Kibana. If they are already running in your environment then you can skip this section.

Download [Elasticsearch](https://www.elastic.co/downloads/elasticsearch) for your platform and install it
```shell
$ tar xzf elasticsearch-8.5.3-darwin-aarch64.tar.gz 
$ cd elasticsearch-8.5.3
$ ./bin/elasticsearch
```

Elasticsearch will be available at http://localhost:9200 


Download [Kibana](https://www.elastic.co/downloads/kibana) for your platform and install it

```shell
$ tar xzf kibana-8.5.3-darwin-aarch64.tar.gz
$ cd cd kibana-8.5.3
$ bin/kibana
```

If you encounter the below error when starting Kibana then check this article for a resolution - [link](https://dzlab.github.io/2022/12/21/kibana-issue/)

```shell
FATAL  Error: dlopen(/Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node, 0x0001): tried: '/Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node' (code signature in <1683A937-8902-34BD-9886-2F1CC674A96E> '/Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node' not valid for use in process: library load disallowed by system policy)
```

It Kibana starts successfully then it should be available at http://localhost:5601  
```shell
$ bin/kibana
[2022-12-21T12:58:37.552+01:00][INFO ][node] Kibana process configured with roles: [background_tasks, ui]
[2022-12-21T12:58:43.152+01:00][INFO ][plugins-service] Plugin "cloudExperiments" is disabled.

Go to http://localhost:5601/?code=242129 to get started.
```

### Packetbeat
First we need to downlaod the binaries of [Packetbeat](https://www.elastic.co/downloads/beats/packetbeat)
```shell
$ tar xzf packetbeat-8.5.3-darwin-aarch64.tar.gz
$ cd packetbeat-8.5.3-darwin-aarch64
```

When trying to start the `packetbeat` process you will encounter this issue
```shell
$ sudo ./packetbeat -e -c packetbeat.yml
Password:

Exiting: error loading config file: config file ("packetbeat.yml") must be owned by the user identifier (uid=0) or root
```

We need to prevent any other user than `root` to modify the configuration file `packetbeat.yml` (for details check [config file permissions](https://www.elastic.co/guide/en/beats/libbeat/current/config-file-permissions.html)).
1. For quick testing we can simply start`packetbeat` with strict mode disabled `-strict.perms=false` as follows:
```shell
$ sudo ./packetbeat -e -c packetbeat.yml -strict.perms=false
```
1. A better option is it to simply change the file owner like this
```shell
sudo chown root ./filebeat/filebeat.yml
sudo chmod go-w ./filebeat/filebeat.yml
```

After starting the `packetbeat` process, I was not able to stop it with a simple `Ctrl+C` or `Ctrl+Z` (it was ignoring those signals). So in a new terminal, I end up using `kill -9` like this
```shell
$ ps aux | grep beat
root             52753   0.7  0.4 409478496  70160 s006  S+   10:30AM   0:02.99 ./packet**beat** -e -c packet**beat**.yml -strict.perms=false
dzlab            53080   0.0  0.0 408628368   1664 s005  S+   10:42AM   0:00.00 grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn --exclude-dir=.idea --exclude-dir=.tox **beat**
root             52752   0.0  0.0 408647952   5568 s006  S+   10:30AM   0:00.02 sudo ./packet**beat** -e -c packet**beat**.yml -strict.perms=false

$ sudo kill -9 52753
```
Now going back to terminal running `packetbeat` I see
```shell
{"log.level":"error","@timestamp":"2022-12-21T10:42:23.433+0100","log.logger":"esclientleg","log.origin":{"file.name":"transport/logging.go","file.line":38},"message":"Error dialing dial tcp [::1]:9200: connect: connection refused","service.name":"packetbeat","network":"tcp","address":"localhost:9200","ecs.version":"1.6.0"}
[1]    52752 killed     sudo ./packetbeat -e -c packetbeat.yml -strict.perms=false
```


## That's all folks


I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).