---
layout: post
comments: true
title: Data Preprocessing with TensorFlow eXtended (TFX)
excerpt: Learn how to use TFDV to generate statistics about your data and turn them into something actionable.
categories: ml
tags: [tensorflow, tfx]
toc: true
img_excerpt:
---

![tfx-components]({{ "assets/2020/11/20201114-tfx-components.svg" | absolute_url }}){: .center-image }

In a previous [article]({{ "ml/2020/09/13/tfx-data-ingestion/" | absolute_url }}), we discussed how we can ingest data from various sources into a TFX pipeline. In another [one]({{ "ml/2020/11/03/tfx-data-validation/" | absolute_url }}) we saw how to use TFX for data validation. In this article, we will discuss the next step of a TFX pipeline which involves data preprocessing and features generation.


Standardising data processing as part of a machine learning pipeline is very import for the following reasons:
* When the data have to be processed as a whole, e.g. when normalizing features (i.e. susbtracting the mean and dividing by the standard deviation).
* To avoid Training-Serving skew by applying the same processing steps (e.g. normalization).
* To avoid mismatch between how the trained model expects data to be and how it is provided.
* To avoid preprocessing to happen in the client as it will be part of the saved model graph and executed by the model server.

TFT creates and saves a TensorFlow graph of the preprocessing steps. First, it will create a graph to process the data (e.g., determine minimum/maximum values). Afterwards, it will preserve the graph with the determined boundaries. This graph can then be used during the inference phase of the model life cycle. This process guarantees that the model in the inference life cycle step sees the same preprocessing steps as the model used during the training.


* TFT uses Apache Beam under the hood to execute preprocessing instructions. This allows us to distribute the preprocessing if needed on the Apache Beam backend of our choice. If you don’t have access to Google Cloud’s Dataflow product or an Apache Spark or Apache Flink cluster, Apache Beam will default back to its Direct Runner mode.

This normalization step usually requires two passes over the data: one pass to determine the boundaries and one to convert each feature value. TFT provides functions to manage the passes over the data behind the scenes for us.

TensorFlow Transform (TFT), the TFX component for data preprocessing, allows us to build our preprocessing steps as TensorFlow graphs.

