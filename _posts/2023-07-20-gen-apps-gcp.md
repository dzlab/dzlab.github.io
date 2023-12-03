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

For example, the following snippet uses the Python SDK to load an LLM and ask for a prediction for the input prompt. In this case we use [PaLM](https://developers.generativeai.google/models/language)'s `text-bison@001` which is capable of many generative tasks including:
- Text generation
- Information extraction
- Code generation
- Recommendations generation
- etc.

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

> Note: the prompt passed to the LLM  is a text that is used to guide the LLM to generate a specific output. In this example it is a simple question, but it could proceeded be a few samples of questions and answers to hint the model about the kind of output answer we are expecting. This is called few-shot learning.

## Generative app with Vertex AI and Cloud Run
Now as we have seen in the previous section how to use the Vertex AI Python SDK to use an LLM to generate text, in this section we will package this in a Flask-based application and deploy it on Cloud Run.

The snippet creates a simple Flask app that uses a Vertex AI Text Generation Model to generate text. The code first imports the necessary libraries, including the vertexai library, the TextGenerationModel class from the vertexai.language_models library, and the Flask library.

The next few lines of code initialize the Vertex AI client and set the project and location. Then, the parameters for the TextGenerationModel are defined. As explained in the previous section, these parameters control the output of the model, such as the temperature, the maximum number of output tokens, and the top-p and top-k values. Then, we create a TextGenerationModel object from the pre-trained `text-bison@001` model. 

After that, we create a Flask app that defines a single route, `/predict`, which accepts `POST` requests and will be handled by the `predict()`. Inside this function we get the prompt from the request and pass it to the model to generate text and return the output as a response to the client.

```python
import vertexai
from vertexai.language_models import TextGenerationModel
from flask import Flask, request

vertexai.init(project="PROJECT_ID", location="REGION")

parameters = {
    "temperature": 0.5,
    "max_output_tokens": 256,
    "top_k": 3,
    "top_p": 0.5
}
model = TextGenerationModel.from_pretrained("text-bison@001")

app = Flask(__name__)

@app.route('/predict', methods= ['POST'])
def predict():
    prompt = request.data
    response = model.predict(prompt, **parameters)
    return response

if __name__ == "__main__":
    app.run(port=8000, host='0.0.0.0', debug=True)
```

To deploy our application to Cloud Run, we bundle it in a Docker image. Let's first declare the dependencies in a `requirements.txt` file:

```
Flask==2.3.3
google-cloud-aiplatform==1.28.1
```

The following `Dockerfile` defines how the image is built by installing the dependencies from `requirements.txt` and running the code in `run.py` to lunch the Flask application, and exposing the right ports so that traffic is routed inside the container.

```Dockerfile
FROM python:3.9

EXPOSE 8000
ENV PORT 8000

RUN groupadd -g 1000 userweb && useradd -r -u 1000 -g userweb userweb

WORKDIR /home
RUN chown userweb:userweb /home

USER userweb

COPY . /home
RUN pip install -r /home/requirements.txt

CMD python3 /home/run.py
```

As a security best practice, we should not run code inside a container as root. Hence in the `Dockerfile` we created a new user (and a group) called `userweb` so that the Flask application will be run as this new user. We also change the ownership of the working directory (i.e. the `/home` directory) to `userweb:userweb`.


Next, we build a Docker image and publish it to Google Cloud Artifact Registry using [Google Cloud CLI](https://cloud.google.com/build/docs/running-builds/submit-build-via-cli-api).

```shell
export IMAGE_NAME=generative-app

gcloud auth login
gcloud config set project $PROJECT_ID
gcloud builds submit --tag gcr.io/$PROJECT_ID/$IMAGE_NAME .
```

Once the image is publish it in Artifact Registry, we can deploy it in Cloud Run using `gcloud` CLI. The following is an example deployment where we run the container using 1 CPU and 512 Mb memory, with minimum and maximum of instances equal to 1 (to avoid many instances getting spinned and controlling cost and):

```shell
exoprt REGION=us-central1

gcloud run deploy generative-app --image gcr.io/$PROJECT_ID/$IMAGE_NAME --min-instances 1 --max-instances 1 --cpu 1 --allow-unauthenticated --memory 512Mi --region $REGION --concurrency 3
```


## That's all folks
GCP has powerful set of services to deploy all sort of applications. In this article, we saw how to combine Vertex AI to build a generative AI application and use Cloud Run to deploy it.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
