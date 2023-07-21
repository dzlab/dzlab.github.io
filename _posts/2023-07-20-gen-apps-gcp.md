---
layout: post
comments: true
title: Deploy Generative applications on GCP with Cloud Run
excerpt: Learn how to deploy generative applications on Google Cloud Platform with Cloud Run
tags: [ai,gcp,genai]
toc: true
img_excerpt:
---

<img align="center" src="/assets/logos/icons8-google-cloud.svg" width="120" />
<br/>

Vertex AI in Google Cloud Platform provides a comprehensive set of tools and services that make it easy to build and deploy generative AI applications. For developpement and testing, Vertex AI provides:

- [Model Garden](https://cloud.google.com/model-garden): Access to foundation models which are pre-trained generative AI models to prototype and test generative AI applications without the need to train your own models. Those models cover tasks for generating text, images, code, and other classical tasks like object detection, etc.
- [Generative AI Studio](https://cloud.google.com/generative-ai-studio): a managed environment called that makes it easy to interact with, tune, and deploy foundation models. It also provides a graphical user interface that allows you to design prompts, test models, and deploy models to production.


Further more, Vertex AI also allows you to customize foundation models through the Vertex AI Custom Training service to train your own models, or through the Vertex AI Model Tuner service to fine-tune foundation models. Then, once you have trained or tuned a model, you can deploy it to production using the Vertex AI Prediction service which provides a scalable and reliable way to serve models.


![Vertex AI]({{ "/assets/2023/07/2023-07-20-vertex-ai.svg" | absolute_url }})



## That's all folks
Vertex AI is a powerful tool that can be used to build a wide variety of generative AI applications.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
