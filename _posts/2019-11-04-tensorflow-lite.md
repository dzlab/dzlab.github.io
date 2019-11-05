---
layout: post
comments: true
title: ML on the Edge with Tensorflow Lite
categories: tensorflow
tags: [lite, optimization]
toc: true
#img_excerpt: 
---

Tensorflow Lite is a framework for deploying tensorflow machine learning models into low resources devices (mobile and IoT).

Deploying a complex ML model on an edge device can be interesting to reduce latency and improve user interaction (e.g. in the presence of network issues or when user is offline). It also addresses privacy concerns as users data will be processed to deliver an intelligent behavior locally without need them to be sent/stored to a remote server.


The full notebook with different conversion examples can be found [here](https://github.com/dzlab/deepprojects/blob/master/tensorflow/Tensorflow_Lite_conversion_examples.ipynb).

## Tensorflow World 2019
During Tensorflow World 2019, a lot of new exciting features for [Tensorflow Lite](https://www.oreilly.com/radar/tensorflow-lite-ml-for-mobile-and-iot-devices/) were introduced.

![tensorflow-lite-progress]({{ "/assets/2019/2019-11-04-tensorflow-lite-progress.png" | absolute_url }}){: .center-image }

Here is the full video from Tensorflow World 2019:
<iframe width="560" height="315" src="https://www.youtube.com/embed/zjDGAiLqGk8" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

