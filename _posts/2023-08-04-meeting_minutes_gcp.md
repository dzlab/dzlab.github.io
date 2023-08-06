---
layout: post
comments: true
title: Meeting minutes generator on GCP with Vertex AI and Cloud Run
excerpt: Learn how to use create a meeting minutes generator on GCP with Vertex AI (Chirp and PaLM) and Cloud Run
tags: [ai,gcp,genai]
toc: true
img_excerpt:
---

<img align="center" src="/assets/logos/icons8-google-cloud.svg" width="120" />
<br/>

Vertex AI is a managed machine learning platform within Google Cloud Platform that helps building, deploying, and scaling machine learning models. It offers a Model Garden which is a collection of ready to use foundation ML models that can be used for different tasks. Examples of such models are Chirp which can be used for speech-related task, and PaLM which is a large language model that can be used for a variety of NLP tasks.

In this article, we'll leverage the power of Vertex AI's to develop an automated meeting minutes generator. The application transcribes audio recoding of a meeting using Chirp, and then uses PaLM to provide a summary of the conversation, extracts keywords and key points, as well as action items, and also performs a sentiment analysis.


In the first part of this article we will build helper functions to transcribe audio recoring of a meeting and generate a summary. In the second part, we will use them to build a Flask application that generates meeting minutes, package it with Docker, and then deploy it to Cloud Run.


## Setup Vertex AI
We need to instantiate the API clients for Chirp and PaLM. Let's create a `lib.py` file and add the necessary initialization logic for both APIs.

```python
import vertexai
from vertexai.language_models import TextGenerationModel
from google.api_core.client_options import ClientOptions
from google.cloud.speech_v2 import SpeechClient
from google.cloud.speech_v2.types import cloud_speech

project_id = "PROJECT_ID"
region = "REGION"

# Instantiates a Chirp client
chirp_api = f"{region}-speech.googleapis.com"
chirp_client = SpeechClient(client_options=ClientOptions(api_endpoint=chirp_api))
chirp_config = cloud_speech.RecognitionConfig(
    auto_decoding_config=cloud_speech.AutoDetectDecodingConfig(),
    language_codes=["en-US"],
    model="chirp",
)

# Instantiates a PaLM client
vertexai.init(project="PROJECT_ID", location="REGION")
palm_parameters = {
    "temperature": 0.5,
    "max_output_tokens": 256,
    "top_k": 3,
    "top_p": 0.5
}
palm_model = TextGenerationModel.from_pretrained("text-bison@001")
```

In the same file, we define the following helper function that wraps the PaLM API client to generate text.

```python
def generate_text(prompt):
    completion = palm_model.predict(prompt, **palm_parameters)
    return completion.text
```

### Transcribe an audio file using Chirp.
Next in the `lib.py` file, we define a helper function that takes a bytes array representing the audio and calls the Chirp API to transcribe the audio to text.

```python
def transcribe_audio(audio_bytes):
    request = cloud_speech.RecognizeRequest(
        recognizer=f"projects/{project_id}/locations/us-central1/recognizers/_",
        config=chirp_config,
        content=audio_bytes,
    )
    response = chirp_client.recognize(request=request)
    transcript = None
    for result in response.results:
        transcript = result.alternatives[0].transcript

    return transcript
```


## Summarizing and analyzing the transcript with PaLM
After transcribing the audio with Chrip, now we use PaLM to generate a summary, extract keywords and key points, action items, and perform sentiment analysis. We then define the following main function `meeting_minutes` that splits up the tasks in separate functions and return a result constructed from executing each task.

```python
def meeting_minutes(transcript):
    abstract_summary = abstract_summary_extraction(transcript)
    key_points = key_points_extraction(transcript)
    action_items = action_item_extraction(transcript)
    keywords = keywords_extraction(transcript)
    sentiment = sentiment_analysis(transcript)
    return {
        'abstract_summary': abstract_summary,
        'key_points': key_points,
        'keywords': keywords,
        'action_items': action_items,
        'sentiment': sentiment
    }
```

> Note: We are using distinct functions for each task we want PaLM to perform. This is not very efficient and not cost effective as we will need one API call for each task. But it should lead to higher quality summarization and also is easier to understand.

In the rest of this section, we will define the individual functions for each step:

### Summary extraction
The following function calls PaLM API to summarizes the transcription into a concise abstract paragraph. It combines the transcript with a prompt that provides PaLM with detailed instructions to perform the summarization.

```python
def abstract_summary_extraction(transcript):
    instructions = "You are a highly skilled AI trained in language comprehension and summarization. I would like you to read the following text and summarize it into a concise abstract paragraph. Aim to retain the most important points, providing a coherent and readable summary that could help a person understand the main points of the discussion without needing to read the entire text. Please avoid unnecessary details or tangential points."
    return generate_text(f"{instructions}\n{transcript}")
```

### Key points extraction
The following function instructs PaLM to identify and list the main ideas/points in the transcript.

```python
def key_points_extraction(transcript):
    instructions = "You are a proficient AI with a specialty in distilling information into key points. Based on the following text, identify and list the main points that were discussed or brought up. These should be the most important ideas, findings, or topics that are crucial to the essence of the discussion. Your goal is to provide a list that someone could read to quickly understand what was talked about."
    return generate_text(f"{instructions}\n{transcript}")
```

> Note: To dramatically improve the model ability to extract relevant information, we shoud provide it in the prompt more context related to meeting. For instance, provide information about the company and its goals like “We are a company that distribute fresh vegetables. We are trying to launch XYZ with the goal of XYZ”.

### Keywords extraction
The following function instructs PaLM to identify and list the main keywords used repetively in the transcript.

```python
def keywords_extraction(transcript):
    instructions = "You are an AI expert in analyzing conversations and extracting keywords. You will be provided with a block of text, and your task is to extract a list of most important keywords from it. Please list the top 10 keywords and use a comma to separate the keywords in the output. "
    return generate_text(f"{instructions}\n{transcript}")
```

### Action item extraction
The next function instructs PaLM to identify tasks, assignments, or actions agreed upon or mentioned during the meeting.

```python
def action_item_extraction(transcript):
    instructions = "You are an AI expert in analyzing conversations and extracting action items. Please review the text and identify any tasks, assignments, or actions that were agreed upon or mentioned as needing to be done. These could be tasks assigned to specific individuals, or general actions that the group has decided to take. Please list these action items clearly and concisely."
    return generate_text(f"{instructions}\n{transcript}")
```

### Sentiment analysis
Next, we define a helper function to analyze the overall sentiment of the discussion and determine if it is positive/neutral/negative. It asks PaLM to consider the tone, the emotions conveyed by the language used, and the context in which words and phrases are used.

```python
def sentiment_analysis(transcript):
    instructions = "As an AI with expertise in language and emotion analysis, your task is to analyze the sentiment of the following text. Please consider the overall tone of the discussion, the emotion conveyed by the language used, and the context in which words and phrases are used. Indicate whether the sentiment is generally positive, neutral, or negative, and provide brief explanations for your analysis where possible."
    return generate_text(f"{instructions}\n{transcript}")
```

## Deploying to Cloud Run
We can now build a Flask application that accepts POST requests with a body representing audio recording and generates the meeting minutes using the helper functions from `lib.py`. We will bundle it in a Docker image so we can deploy it to Cloud Run.

Let's first, define the Flask application in a `app.py` file as follows:

```python
from lib import meeting_minutes, transcribe_audio
from flask import Flask, request

app = Flask(__name__)

@app.route('/generate', methods= ['POST'])
def generate():
    audio_bytes = request.files['file'].read()
    transcript = transcribe_audio(audio_bytes)
    response = meeting_minutes(transcript)
    return response

if __name__ == "__main__":
    app.run(port=8000, host='0.0.0.0', debug=True)
```

Then declare the dependencies in a `requirements.txt` file:

```
Flask==2.3.3
google-cloud-aiplatform==1.29.0
google-cloud-speech=2.21.0
```

The following `Dockerfile` defines how the image is built by:
- Installing the dependencies from `requirements.txt`
- Copying the application files `lib.py` and `app.py`
- Exposing the right ports so that traffic is routed inside the container.
- Running the code in `app.py` to lunch the application

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

CMD python3 /home/app.py
```

Next, using [Google Cloud CLI](https://cloud.google.com/build/docs/running-builds/submit-build-via-cli-api), we build a Docker image and publish it to Google Cloud Artifact Registry.

```shell
export IMAGE_NAME=meeting-minutes

gcloud auth login
gcloud config set project $PROJECT_ID
gcloud builds submit --tag gcr.io/$PROJECT_ID/$IMAGE_NAME .
```

Once the image is publish it to Artifact Registry, we can deploy it in Cloud Run. 

The following is an example deployment where we run the container using 1 CPU and 512 Mb memory, with minimum and maximum of instances equal to 1 (to avoid many instances getting spinned and controlling cost and):

```shell
exoprt REGION=us-central1

gcloud run deploy meeting-minutes --image gcr.io/$PROJECT_ID/$IMAGE_NAME --min-instances 1 --max-instances 1 --cpu 1 --allow-unauthenticated --memory 512Mi --region $REGION --concurrency 3
```


## That's all folks
In this article we saw how easy it is to use services from Google Cloud to build innovative applications. In this case, we used two foundation models from Vertex AI: Chirp and PaLM. Then created an application to generate meeting minutes, and we deployed it to Cloud Run.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
