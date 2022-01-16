---
layout: post
comments: true
title: GCP Machine Learning Engineer Certification Preparation Guide
excerpt: Tips and topics to get ready for passing Google Machine Learning Engineer Certification.
categories: certification
tags: [gcp,data,machinelearning,certification]
toc: true
img_excerpt:
---

<center><img alt="Professional Machine Learning Engineer Certification" src='https://templates.images.credential.net/15929551215786304368956491751126.png' width='300' height='300'></center>


I recently passed Google Professional Machine Learning Engineer Certification, during the preparation I went throught lot resources about the exam. The exam is relatively eaiser than the Data engineer certification exam as the questions are more direct (almost no ambigous question) but it has 60 questions instead of the typical 50. It focuses on the following areas:

- Knowledge of ML concepts, problems (classification vs regression), tools (sklearn vs Tensorflow)
- Knowledge of GCP ML products (AI Platform, ML APIs, BQML) and when to use them.
- Knowledge of MLOps concepts (e.g. Continuous training) and tools (TFX vs Kubeflow).

I could not find a comprehensive resource that covers all aspect of the exam when I started preparing. I had to go over a lot of Google Cloud products page and general Machine Learning resources and at no point I felt ready as both topics are huge. Here I will try to provide a summary of the resources I did found helpful for passing the exam.


## Machine Learning
Big part of the exam are general ML questions that touches concept not specific to Google. This is a huge topic by itself but it should be enough for the exam to go over most of the materials in [Google ML Crash Course](https://developers.google.com/machine-learning/)
- Introduction to Machine Learning Problem Framing - [link](https://developers.google.com/machine-learning/problem-framing)
- Data Preparation and Feature Engineering for Machine Learning - [link](https://developers.google.com/machine-learning/data-prep)
- Clustering in Machine Learning - [link](https://developers.google.com/machine-learning/clustering)
- Recommendation Systems - [link](https://developers.google.com/machine-learning/recommendation)
- Testing and Debugging in Machine Learning - [link](https://developers.google.com/machine-learning/testing-debugging)

Also you should get familliar with Privacy in Machine Learning - [link](https://ai.google/responsibilities/responsible-ai-practices/?category=privacy)

### Metrics
You need to know what are the metrics you can use and for what kind of ML problem they can be applied to. For instance, for a Classification problem you can use:
- ROC Curve and AUC - [link](https://developers.google.com/machine-learning/crash-course/classification/roc-and-auc)
- Precision - (True Positives) / (All Positive Predictions) - When model said “positive” class, was it correct?
- Recall - (True Positives) / (All Actual Positives) - Out of all possible positives, how many did the model correctly identify?
### Regularization
Regularization is usually applied to combat overfitting by penalizing model complexity for a better generalization. You need to know the different regularization techniques (see below) and when to use them. Most of the questions won't be direct but will present you a senario (e.g. training performance excedes test one) and you will be asked what should you do.

**Regularization techniques**
- L1 Regularization - A type of regularization that penalizes weights in proportion to the sum of the absolute values of the weights. In models relying on sparse features, L1 regularization helps drive the weights of irrelevant or barely relevant features to exactly 0, which removes those features from the model.
- [L2 Regularization](https://developers.google.com/machine-learning/crash-course/regularization-for-simplicity/l2-regularization) - A type of regularization that penalizes weights in proportion to the sum of the squares of the weights. L2 regularization helps drive outlier weights (those with high positive or low negative values) closer to 0 but not quite to 0. L2 regularization always improves generalization in linear models.
- [Dropout Regularization](https://developers.google.com/machine-learning/crash-course/training-neural-networks/best-practices#dropout-regularization) -Randomly shut off neurons for a training step thus preventing preventing training. The more you drop out, the stronger the regularization. Helps with Overfitting, too much can lead to underfitting.
- Other methods include: Early stopping, Max-norm regularization, Dataset Augmentation, Noise robustness, Sparse representation.

### Neural Networks
Some common issues with Neural Networks training and how to address them:

- [Vanishing Gradients](https://developers.google.com/machine-learning/crash-course/training-neural-networks/best-practices#vanishing-gradients) - The gradients for the lower layers (closer to the input) can become very small. When the gradients vanish toward 0 for the lower layers, these layers train very slowly, or not at all. The ReLU activation function can help prevent vanishing gradients.
- [Exploding Gradients](https://developers.google.com/machine-learning/crash-course/training-neural-networks/best-practices#exploding-gradients) - If the weights in a network are very large, then the gradients for the lower layers involve products of many large terms. In this case you can have exploding gradients: gradients that get too large to converge. Batch normalization can help prevent exploding gradients, as can lowering the learning rate.
- [Dead ReLU Units](https://developers.google.com/machine-learning/crash-course/training-neural-networks/best-practices#dead-relu-units) - Once the weighted sum for a ReLU unit falls below 0, the ReLU unit can get stuck. It outputs 0 activation, contributing nothing to the network’s output, and gradients can no longer flow through it during backpropagation. With a source of gradients cut off, the input to the ReLU may not ever change enough to bring the weighted sum back above 0.. Lowering the learning rate can help keep ReLU units from dying. !!Leaky-Relu can help to address this, as can choice of optimiser eg. ADAM!!

To summaries:
- Vanishing gradients: use ReLu
- Exploding gradients: use batch normalization
- ReLu layers are dying: lower learning rates

### AI Explanations
[Explainable AI](https://cloud.google.com/explainable-ai) is another topic to know about and the different techniques available to explain a model.
- For structured data, Shapely is a popular technique to use
- Integrated ingredients can be used for large feature spaces;
- For images data, use integrated gradients for pixel-level explanations or XRAI for region-level explanations.

Also, an important tool to know about is [WhatIf Tool](https://pair-code.github.io/what-if-tool/) — when do you use it? How do you use it? How do you discover different outcomes? How do you conduct experiments?

## Tensorflow

You need to know basic model architectures, layers (e.g. dense, dropout, convolutional, pooling) and which one define training parameters. Also, knowing the Keras API is important.

- How to build a model: use the Sequential API by default. If you have multiple inputs or outputs, layer sharing or a non-linear topology, change to the Functional API, unless you have a RNN. If that is the case, Keras Subclasses instead.
- How to improve if data pre-processing is a bottleneck, do it offline as a one-time cost; choose the larges batch size that fits in memory; keep the per-core batch size the same
- How to use the `tf.data` API for the input processing and enabling parallelism with `interleave` - [link](https://dzlab.github.io/dltips/en/tensorflow/tfdata-performance/)
- How to use use TF [feature column API](https://www.tensorflow.org/api_docs/python/tf/feature_column) to perform feature engineering in TensorFlow and how to produce the following features: numerical, categorical one-hot encoded/embedded/hashed, bucketized one-hot encoded/embedded/hashed, crossed.
- How to use TensorBoard and TF Profiler for troubleshooting - [link](https://www.tensorflow.org/guide/profiler)

### Accelerators
You need to know the differences between CPUs, TPUs and GPUs and when to use each one. The general answer is that GPU training is faster than CPU training, and GPU usually doesn’t require any additional setup. TPUs are faster than GPUs but they don't support custom operations.

- Use CPUs for quick prototypes, simple/small models or if you have many C++ custom operations;
- Use GPU if you have some custom C++ operations and/or medium to large models;
- Use TPUs for big matrix computations, no custom TensorFlow operations and/or very large models that train for weeks or months

You may also want learn about basic troubleshooting - [link](https://cloud.google.com/tpu/docs/troubleshooting)
### Distributed training

You need to know the differences between the different Distributed training strategies in Tensorflow [link](https://www.tensorflow.org/guide/distributed_training).

|Strategy|Synchronous / Asynchronous|Number of nodes|Number of GPUs/TPUs per node|How model parameters are stored|
|-|-|-|-|-|
|[MirroredStrategy](https://www.tensorflow.org/guide/distributed_training#mirroredstrategy)|Synchronous|one|many|On each GPU|
|TPUStrategy|Synchronous|one|many|On each TPU|
|MultiWorkerMirroredStrategy|Synchronous|many|many|On each GPU on each node|
|ParameterServerStrategy|Asynchronous|many|one|On the Parameter Server|
|CentralStorageStrategy|Synchronous|one|many|On CPU, could be placed on GPU if there is only one|
|Default Strategy|no distribution|one|one|on any GPU picked by TensorFlow|
|OneDeviceStrategy|no distribution|one|one|on the specified GPU|


Make also sure to know the components of a distributed training architecture: master, worker, parameter server, evaluator, and how many of each you can get.


## MLOps
- MLOps: Continuous delivery and automation pipelines in machine learning - [link](https://cloud.google.com/solutions/machine-learning/mlops-continuous-delivery-and-automation-pipelines-in-machine-learning)
- End to end hybrid and multi-cloud ML workloads - [link](https://www.kubeflow.org/docs/about/use-cases/#end-to-end-hybrid-and-multi-cloud-ml-workloads)

### TFX
You have to know TFX (TensorFlow Extended) and its limitations (can be used to build pipelines for Tensoflow models only), what are its standard components (e.g. ingestion, validation, transform) and how to build a pipeline out of them.

- TFX on Cloud AI Platform Pipelines - [link](https://www.tensorflow.org/tfx/tutorials/tfx/cloud-ai-platform-pipelines)
- TFX pipelines and components — https://www.tensorflow.org/tfx/guide/understanding_tfx_pipelines
- Architecture for MLOps using TFX, Kubeflow Pipelines, and Cloud Build - [link](https://cloud.google.com/solutions/machine-learning/architecture-for-mlops-using-tfx-kubeflow-pipelines-and-cloud-build)

### Kubeflow
You need to know Kubeflow and that you should use if your modeling framework is not TensorFlow (i.e. when you need PyTorch, XGBoost) or if you want to dockerize every step of the flow - [link](https://www.kubeflow.org/docs/pipelines/overview/pipelines-overview/)
- How to carry out CI/CD in Machine Learning (“MLOps”) using Kubeflow ML pipelines (#3) - [link](https://medium.com/google-cloud/how-to-carry-out-ci-cd-in-machine-learning-mlops-using-kubeflow-ml-pipelines-part-3-bdaf68082112)
- Kubeflow (kfctl) GitHub Action for AI/ML CI/CD - [link](https://github.com/marketplace/actions/kubeflow-for-ci-cd)

### CI/CD
- AB and Canary testing
- Split traffic in production with small portion going to a new version of the model and verify that all metrics are as expcted, gradually increase the traffic split or rollback.
## Google Cloud
You need to know what are the products availble in Google Cloud that can be used to solve ML problems and when to use each one: BigQuery ML, GCP ML APIs, Natural Language API, Vision API, Audio API.

Here is a flow chart to help with deciding what Google ML product to use depending on the situation:

![gcp-ml-decision-flow]({{ "assets/2022/01/20220108-gcp-ml-decision-flow.svg" | absolute_url }}){: .center-image }
### BigQuery ML
BigQuery is a managed data warehouse service, it also has ML capabilities. So if you see a question where the data is in BigQuery and the output will also be there then a natural answer is to use BigQuery ML for modeling.
- What all can you do with BigQuery ML? What are its limitations - [link](https://cloud.google.com/bigquery-ml/docs/introduction)
- Use it for quick and easy models, prototyping etc. - [link](https://cloud.google.com/bigquery-ml/docs/tutorials)
- It supports the following types of model: linear regression, binary and multiclass logistic regression, k-means, matrix factorization, time series, boosted trees, deep neural networks, AutoML models and imported TensorFlow models - [link](https://cloud.google.com/bigquery-ml/docs/reference/standard-sql/bigqueryml-syntax-create)
- Example of training with BigQuery ML - [link](https://towardsdatascience.com/lessons-learned-using-google-cloud-bigquery-ml-dfd4763463c)
- How to do online prediction with BigQuery ML - [link](https://towardsdatascience.com/how-to-do-online-prediction-with-bigquery-ml-db2248c0ae5)

### AI Platform
You need to know AI Platform, built-in algorithms, hyperparameter tuning, and distributed training and what container images to use based on your modeling framework (e.g. tensorflow, pytorch, xgboost, sklearn). The following resources covers most of what you need to know for the exam:

- AI Platform Training - [link](https://cloud.google.com/ai-platform/training/docs)
  - Built-in algos - [link](https://cloud.google.com/ai-platform/training/docs/algorithms)
  - Machine types and scale tiers - [link](https://cloud.google.com/ai-platform/training/docs/machine-types)
  - Monitoring - [link](https://cloud.google.com/ai-platform/training/docs/monitor-training)
  - Training and prediction with TF Estimator - [link](https://cloud.google.com/ai-platform/docs/getting-started-keras)
  - Training with scikit-learn and XGBoost - [link](https://cloud.google.com/s/results/?q=scikit-learn&p=%2Fml-engine%2Fdocs%2F).
- AI Platform Prediction - [link](https://cloud.google.com/ai-platform/prediction/docs)
- AI Platform DL containers - [link](https://cloud.google.com/ai-platform/deep-learning-containers/docs)
- AI Platform explanation - [link](https://cloud.google.com/ai-platform/prediction/docs/ai-explanations/overview)
- AI Platform continuous evaluation - [link](https://cloud.google.com/ai-platform/prediction/docs/continuous-evaluation)
- AI Platform pipelines - [link](https://cloud.google.com/ai-platform/pipelines/docs)
- AI Platform Vizier: black-box optimization service that helps tune hyperparameters in complex ML models - [link](https://cloud.google.com/ai-platform/optimizer/docs)

### Natural Language
- Natural Language API - [link](https://cloud.google.com/natural-language/docs/reference/rest)
- AutoML Natural Language API - [link](https://cloud.google.com/natural-language/automl/docs/tutorial)

#### AutoML API
Train your own high-quality machine learning custom models to classify, extract, and detect sentiment with minimum effort and machine learning expertise using Vertex AI for natural language, powered by AutoML. You can use the AutoML UI to upload your training data and test your custom model without a single line of code. - [link](https://cloud.google.com/natural-language/automl/docs/quickstart)
- AutoML Healthcare - [link](https://cloud.google.com/natural-language/automl/docs/automl-healthcare)
- Vertex AI - [link](https://cloud.google.com/vertex-ai/docs/tutorials/text-classification-automl)

#### Natural Language API
The powerful pre-trained models of the Natural Language API empowers developers to easily apply natural language understanding (NLU) to their applications with features including sentiment analysis, entity analysis, entity sentiment analysis, content classification, and syntax analysis. - [link](https://cloud.google.com/natural-language/docs/quickstarts)

#### Healthcare Natural Language AI
Gain real-time analysis of insights stored in unstructured medical text. Healthcare Natural Language API allows you to distill machine-readable medical insights from medical documents, while AutoML Entity Extraction for Healthcare makes it simple to build custom knowledge extraction models for healthcare and life sciences apps—no coding skills required. - [link](https://cloud.google.com/healthcare/docs/how-tos/nlp)

### Translation
Cloud Translation API helps: Translating text, Discovering supported languages, Detecting language of Text, Creating and using glossaries when translating.
- How-to Guides [link](https://cloud.google.com/translate/docs/how-to)
- AutoML Translation - [link](https://cloud.google.com/translate/automl/docs/quickstart)

### Vision AI
Create a dataset of images, train a custom AutoML for Cloud or Edge, then deploy it. If Edge is target you can then export the model in TF Lite, TF.js, CoreML, or Coral Edge TPU.

- Cloud-hosted model quickstart - [link](https://cloud.google.com/vision/automl/docs/quickstart)
- Edge device model quickstart - [link](https://cloud.google.com/vision/automl/docs/edge-quickstart)
- AutoML Vision Prediction: [individual](https://cloud.google.com/vision/automl/docs/predict) and [batch](https://cloud.google.com/vision/automl/docs/predict-batch)

### Video AI
- Video Intelligence API: Face detection, Detect people, Detect shot changes, Explicit Content Detection, Object tracking, Recognize logos(detect, track, and recognize the presence of over 100,000 brands and logos in video content), Text Detection performs Optical Character Recognition (OCR), audio track transcription - [link](https://cloud.google.com/video-intelligence/docs/quickstarts)
- AutoML Video Intelligence: train custom model for classification and object tracking - [link](https://cloud.google.com/video-intelligence/automl/docs/quickstart)

### Other products
- AutoML: Natural Language, Tables, Translation, Video Intelligence, Vision - [link](https://cloud.google.com/automl/docs)
- AI Platform Data Labeling Service - [link](https://cloud.google.com/ai-platform/data-labeling/docs)
- AutoML Tables Quickstart - [link](https://cloud.google.com/automl-tables/docs/quickstart)

## Certification SWAG
After passing the exam, you can choose one of the official certification swags:

![ml-engineer-certification-swags]({{ "assets/2022/01/20220108-certification-swags.png" | absolute_url }}){: .center-image }
