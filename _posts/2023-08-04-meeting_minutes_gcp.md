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

In this tutorial, we'll harness the power of OpenAI's Whisper and GPT-4 models to develop an automated meeting minutes generator. The application transcribes audio from a meeting, provides a summary of the discussion, extracts key points and action items, and performs a sentiment analysis.

https://platform.openai.com/docs/tutorials/meeting-minutes

## Transcribing audio with Chirp

https://cloud.google.com/speech-to-text/v2/docs/chirp-model

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

### Transcribe an audio file using Chirp.

```python
def transcribe_audio(audio_content_bytes) -> cloud_speech.RecognizeResponse:
    request = cloud_speech.RecognizeRequest(
        recognizer=f"projects/{project_id}/locations/us-central1/recognizers/_",
        config=chirp_config,
        content=audio_content_bytes,
    )

    # Transcribes the audio into text
    response = chirp_client.recognize(request=request)

    for result in response.results:
        print(f"Transcript: {result.alternatives[0].transcript}")

    return response
```

```python
def generate_text(prompt):
    completion = palm_model.predict(prompt, **palm_parameters)
    return completion.text
```

## Summarizing and analyzing the transcript with PaLM


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

### Summary extraction
```python
def abstract_summary_extraction(transcript):
    instructions = "You are a highly skilled AI trained in language comprehension and summarization. I would like you to read the following text and summarize it into a concise abstract paragraph. Aim to retain the most important points, providing a coherent and readable summary that could help a person understand the main points of the discussion without needing to read the entire text. Please avoid unnecessary details or tangential points."
    return generate_text(f"{instructions}\n{transcript}")
```

### Key points extraction
```python
def key_points_extraction(transcript):
    instructions = "You are a proficient AI with a specialty in distilling information into key points. Based on the following text, identify and list the main points that were discussed or brought up. These should be the most important ideas, findings, or topics that are crucial to the essence of the discussion. Your goal is to provide a list that someone could read to quickly understand what was talked about."
    return generate_text(f"{instructions}\n{transcript}")
```

### Keywords extraction
```python
def keywords_extraction(transcript):
    instructions = "You will be provided with a block of text, and your task is to extract a list of keywords from it. Please list the top 10 keywords and use a comma to separate the keywords in your output. "
    return generate_text(f"{instructions}\n{transcript}")
```

### Action item extraction
```python
def action_item_extraction(transcript):
    instructions = "You are an AI expert in analyzing conversations and extracting action items. Please review the text and identify any tasks, assignments, or actions that were agreed upon or mentioned as needing to be done. These could be tasks assigned to specific individuals, or general actions that the group has decided to take. Please list these action items clearly and concisely."
    return generate_text(f"{instructions}\n{transcript}")
```

### Sentiment analysis
```python
def sentiment_analysis(transcript):
    instructions = "As an AI with expertise in language and emotion analysis, your task is to analyze the sentiment of the following text. Please consider the overall tone of the discussion, the emotion conveyed by the language used, and the context in which words and phrases are used. Indicate whether the sentiment is generally positive, neutral, or negative, and provide brief explanations for your analysis where possible."
    return generate_text(f"{instructions}\n{transcript}")
```

## Deploying to Cloud Run

```python
from flask import Flask, request

app = Flask(__name__)

@app.route('/predict', methods= ['POST'])
def predict():
    audio_bytes = request.files['file'].read()
    transcript = transcribe_audio(audio_bytes)
    response = meeting_minutes(transcript)
    return response

if __name__ == "__main__":
    app.run(port=8000, host='0.0.0.0', debug=True)
```

To deploy our application to Cloud Run, we bundle it in a Docker image. Let's first declare the dependencies in a `requirements.txt` file:


```
Flask==2.3.3
google-cloud-aiplatform==1.29.0
google-cloud-speech=2.21.0
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

Next, we build a Docker image and publish it to Google Cloud Artifact Registry using [Google Cloud CLI](https://cloud.google.com/build/docs/running-builds/submit-build-via-cli-api).

```shell
export IMAGE_NAME=meeting-minutes

gcloud auth login
gcloud config set project $PROJECT_ID
gcloud builds submit --tag gcr.io/$PROJECT_ID/$IMAGE_NAME .
```

Once the image is publish it in Artifact Registry, we can deploy it in Cloud Run using `gcloud` CLI. The following is an example deployment where we run the container using 1 CPU and 512 Mb memory, with minimum and maximum of instances equal to 1 (to avoid many instances getting spinned and controlling cost and):

```shell
exoprt REGION=us-central1

gcloud run deploy meeting-minutes --image gcr.io/$PROJECT_ID/$IMAGE_NAME --min-instances 1 --max-instances 1 --cpu 1 --allow-unauthenticated --memory 512Mi --region $REGION --concurrency 3
```


## That's all folks
I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
