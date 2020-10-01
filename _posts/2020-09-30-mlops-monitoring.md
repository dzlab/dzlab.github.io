---
layout: post
comments: true
title: Monitoring Machine Learning models
categories: ml
tags: [mlops, monitoring]
toc: true
img_excerpt: assets/2020/09/20200930-monitoring-dashboard-excerpt.png
---

![monitoring-dashboard]({{ "assets/2020/09/20200930-monitoring-dashboard.png" | absolute_url }}){: .center-image }



To ensure service continuity and a minimum SLA (Service Level Agreement), traditional applications are deployed along with a monitoring system. Such system is used to log metrics like request frequency, latency, and server load in order to take actions like raising alerts in case the service is interrupted.

Similarly, as part of an MLOps paradigm, Machine Learning deployments need to be monitored to keep track of models health and in order to take actions whem performance metrics is degraded. We should not loose track of the fact that trained models come with performance metrics on offline datasets which does not guarantee performance when it goes live.
Unfortunately, this task of monitoring models is very challenging as there is lack of tools, systems and even a common understanding among the MLOps community of what an ML monitoring system should look like.

However, there are tools that ML practicioners use during training that can be also used during model deployment, for instance model performance metrics and model explainabity techniques. But this is not enough as another dimension that need to monitored is the data itself that the model is receive to generate predictions. Take as exmaple, a model which was trained on cat pictures but sudenly during deployment starts getting dog pictures (such problem is called Data drifting). Furthermore, the presence of outliers in the new data can significantly degrade the deployed model performance.

To be continued.