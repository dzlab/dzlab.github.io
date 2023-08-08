---
layout: post
comments: true
title: Serverless Meeting minutes generator on GCP with Vertex AI and Cloud Functions
excerpt: Learn how to create a Serverless meeting minutes generator on GCP with Vertex AI (Chirp and PaLM) Cloud Functions and PubSub
tags: [ai,gcp,genai]
toc: true
img_excerpt:
---

![GCP Serverless Meeting minutes generator architecture]({{ "/assets/2023/08/20230807-serverless-meeting-minutes-architecture-gcp.svg" | absolute_url }})

GCP is a powerful platform for building all sort of applications. It hosts a variety of services which are scalable, reliable, cost-effective, easy to use, and can be easily integrated together.

In a previous article, we saw [how to leverage GCP's Vertex AI to develop an automated meeting minutes generator]({{ "/2023/08/04/meeting_minutes_gcp/" }}). In this article, we will re-architecture that application to make it more scalable and capable of processing audio recordings asynchronously. We will use Cloud Storage to host the recordings, and use Cloud Functions and PubSub to trigger the processing as new recordings are uploaded. For the speach to text and summary generation, we will use Chirp and PaLM from Vertex AI.

## Infrastructure setup

The above diagram illustrates a high level architecture for our serverless meeting minutes generator application.

Audio recording files are uploaded to a Cloud Storage bucket. Every time, a new recording is uploaded an new entry is appended to PubSub queue with information about the file. This triggers a Cloud Function that will process the recoding, generate the meeting minutes and then save them to a Cloud Storage bucket.

When the generation of minutes fail within the Cloud Function, the original Cloud Storage event will be forwarded to a [Dead-Letter Queue (DLQ)](https://cloud.google.com/pubsub/docs/handling-failures), and then sent back to the main queue for reprocessing.

We will use Cloud Deployment Manager to provision all the needed services. Let's configure the different resources as follows:
```yaml
resources:

# PubSub queue for notifications when audio files are uploaded
- name: recordings-upload-topic
  type: pubsub.v1.topic
  properties:
    name: recordings-upload-topic

# Cloud Storage bucket where audio files will be uploaded
- name: recordings-bucket
  type: storage.v1.bucket
  properties:
    name: recordings-bucket
    location: us-central1
    storageClass: STANDARD
    notificationConfig:
      topic: recordings-upload-topic
      eventTypes:
        - OBJECT_FINALIZE
```

Save the content of the previous snippet into a `resources.yaml` file then use `gcloud` to provision them as follows:

```shell
gcloud deployment-manager deployments create logs-deployment --config resources.yaml
```

> Note: For more information on configuring Pub/Sub notifications to send information about changes to objects in a bucket, check the official documentation on [pubsub notifications](https://cloud.google.com/storage/docs/pubsub-notifications).

## Minutes generation
For generating the meeting minutes, we will use the same code from previous article on [how to leverage GCP's Vertex AI to develop an automated meeting minutes generator]({{ "/2023/08/04/meeting_minutes_gcp/" }}) with one small change as illustrated by the following `diff` patch:

```diff
    request = cloud_speech.RecognizeRequest(
        recognizer=f"projects/{project_id}/locations/us-central1/recognizers/_",
        config=chirp_config,
-       content=audio_bytes,
+       uri=gcs_uri,
    )
```

Instead of passing the audio in the body of the request sent to Chirp, we will pass a URI to where the audio file is stored in a Cloud Storage bucket. For examples on how to Chrip API with GS refer to this [snippet](https://github.com/GoogleCloudPlatform/python-docs-samples/blob/main/speech/snippets/transcribe_gcs_v2.py). 

With this change, our `transcribe_audio` function becomes:

```python
def transcribe_audio(gcs_uri):
    """Transcribes audio from a Google Cloud Storage URI"""
    request = cloud_speech.RecognizeRequest(
        recognizer=f"projects/{project_id}/locations/us-central1/recognizers/_",
        config=chirp_config,
        uri=gcs_uri,
    )
    response = chirp_client.recognize(request=request)
    transcript = None
    for result in response.results:
        transcript = result.alternatives[0].transcript

    return transcript
```

## Deploying to Cloud Function
After creating the logic to generate meeting minutes from recordings, we can now expose this functionality in a Cloud Function.

In a `main.py` file, add the following snippet of a [Cloud Function V2](https://codelabs.developers.google.com/codelabs/cloud-starting-cloudfunctions-v2) that accepts a [CloudEvent](https://github.com/cloudevents/sdk-python) as input. It also register the `cloudevent_handler` method with the Functions Framework so that it will be invoked with proper input.

Upon receiving the event, the `cloudevent_handler` method will be called to extract the path to the audio recordings file and uses `meeting_minutes` and `transcribe_audio` to generate the meeting minutes, then upload them to Google Storage.

```python
import os
from cloudevents.http import CloudEvent
import functions_framework
from lib import meeting_minutes, transcribe_audio

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT")

def upload_to_gcs(bucket_name, file_name, file_content):
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(file_name)

def cloudevent_handler(cloud_event: CloudEvent) -> None:
    print(f"Received event with ID: {cloud_event['id']} and data {cloud_event.data}")
    # Get the bucket and file name from the event.
    data = cloud_event.data["message"]["data"]
    gs_uri = f"gs://{data["bucket"]}/{data["name"]}"
    # Generate meeting minutes
    transcript = transcribe_audio(gs_uri)
    minutes = meeting_minutes(transcript)
    # Upload 
    upload_to_gcs(data["bucket"], data["name"] + ".txt", minutes)

if __name__ == "__main__":
  # Register the function with the Functions Framework.
  functions_framework.cloud_event(cloudevent_handler)
```

> Note: we could also have used the `@functions_framework.cloud_event` decorator to register our handler with the Functions Framework


In the same directory as the previous `main.py`, define a `requirements.txt` file to declare all of our dependencies:

```
cloudevents
functions_framework=3.*
google-cloud-aiplatform==1.29.0
google-cloud-speech=2.21.0
google-cloud-storage
```

Finally, we can deploy our Cloud Function using the `gcloud` CLI from the same directory containing the source code as follows

```shell
gcloud functions deploy minutes-function \
  --gen2 \
  --runtime python39 \
  --entry-point cloudevent_handler \
  --source . \
  --region $REGION \
  --trigger-topic $TOPIC
```

Alternatively, we could have also deployed the function to Cloud Run. All we needed to do is to define a Dockerfile to manually install the dependencies and package the source code. Then, build and deploy the container as with any typical Cloud Run application.

The following `Dockerfile` is an example of how we would define the Container image. For more details refer to official example on how deploying a CloudEvent Function to Cloud Run with the Functions Framework - [link](https://github.com/GoogleCloudPlatform/functions-framework-python/tree/main/examples/cloud_run_cloud_events).


```Dockerfile
FROM python:3.9-slim

ENV PYTHONUNBUFFERED TRUE

WORKDIR /app
COPY . .

RUN pip install -r requirements.txt

CMD ["functions-framework", "--target=cloudevent_handler", "--signature-type=cloudevent"]
```

> Note how on container startup we invoke the Functions Framework in a `CMD` step and specify the `cloudevent_handler` as the entry point function.

## That's all folks
In this article we saw how easy it is to use Google Cloud to build innovative and scalable applications. We used the following services from GCP:
- Cloud Storage to store audio files and
- PubSub to react to events such us when a new audio file is uploaded to Cloud Storage. 
- Cloud Functions used to process meeting recording files and generating the minutes.
- Two foundation models from Vertex AI: Chirp for speech to text and PaLM for text generation.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
