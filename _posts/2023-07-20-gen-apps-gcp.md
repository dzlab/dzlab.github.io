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

In the rest of this article, we will be building Generative application by using only plain API/SDK from Vertex AI without going through services like [Gen App Builder](https://cloud.google.com/blog/products/ai-machine-learning/create-generative-apps-in-minutes-with-gen-app-builder).

![Vertex AI]({{ "/assets/2023/07/2023-07-20-vertex-ai.svg" | absolute_url }})
*Google Cloud Generative AI services*

## Generative AI with Vertex AI Python SDK
Using the [Python SDK for Vertex AI](https://cloud.google.com/vertex-ai/docs/python-sdk/use-vertex-ai-python-sdk) we can build Generative AI applications as it provides an API for interacting with LLMs (large language models). The SDK let us load an LLM from Google Cloud and use it to generate text, translate languages, write different kinds of generative tasks. It also provide ways to fine-tune an LLM on a specific task and then deploy it.

For example, the following snippet uses the Python SDK to load an LLM (in this case `text-bison@001`) and ask for a prediction for the input prompt.

> Note: the prompt passed to the LLM  is a text that is used to guide the LLM to generate a specific output. In this example it is a simple question, but it could proceeded be a few samples of questions and answers to hint the model about the kind of output answer we are expecting. This is called few-shot learning.

```python
import vertexai
from vertexai.language_models import TextGenerationModel

vertexai.init(project="PROJECT_ID", location="us-central1")
parameters = {
    "temperature": 0.5,
    "max_output_tokens": 256,
    "top_k": 3,
    "top_p": 0.5
}
model = TextGenerationModel.from_pretrained("text-bison@001")
prompt = "What is PaLM good for?"
completion = model.predict(prompt, **parameters)
```

In the above snippet, we pass to the LLM some parameters that will control the randomness of the output and thus its quality/relevance. This is a brief examplanation of what does each parameter stand for:

- `temperature`: The higher the value the more random, diverse/creative the response will be.
- `max_output_tokens`: the Token limit is the amount of text the LLM will generate.
- `top_k`: The top k most probable tokens from which the next token is selected. A higher value of k will result in more randomness, while a lower value will result in less randomness and an output that is likely to be relevant and coherent. 
- `top_p`: the threshold of cumulative probability of a range of tokens in the output, i.e. the next token will be selected from the top tokens whose sum of probabilities is greater than or equal to `p`. A higher value of `p` will result in more randomness, while a lower value will result in less randomness.



## That's all folks
Vertex AI is a powerful tool that can be used to build a wide variety of generative AI applications.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
