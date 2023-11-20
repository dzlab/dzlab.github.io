---
layout: post
comments: true
title: ML Pipelines on GCP with Vertex AI
excerpt: Get started building training pipelines on GCP with Vertex AI
tags: [genai,palm]
toc: true
img_excerpt:
---


[Vertex AI Pipelines](https://cloud.google.com/vertex-ai/docs/pipelines) are a platform for building and running machine learning workflows on Google Cloud Platform. They allow the orchestration of machine learning tasks using pre-built or custom components, and leverage the serverless and scalable infrastructure of Vertex AI.

Vertex AI Pipelines is based on the open source Kubeflow Pipelines, but they the two have some differences in terms of features, implementation, and integration:

|Kubeflow Pipelines|Vertex AI Pipelines|
|-|-|
|Open-source project that runs on Kubernetes clusters| A managed service that runs on Google Cloud Platform.|
|You to manage your own infrastructure and cluster maintenance| It handles these tasks for you in a serverless manner.|
|Supports pipelines built using the Kubeflow Pipelines SDK v1 or v2 domain-specific language (DSL)| Supports pipelines built using the Kubeflow Pipelines SDK v2 DSL or TFX v0.30.0 or later.|
|Allows you to group pipeline runs into experiments and track their metrics| Supports TensorBoard and Vizier for visualization and hyperparameter tuning.|
|Lets you use Kubernetes resources such as persistent volume claims for data storage| Requires you to use Cloud Storage and mounts your data using Cloud Storage FUSE.|
|Has some features that are not supported in Vertex AI Pipelines, such as cache expiration and recursion| Has some features that are not supported in Kubeflow Pipelines, such as Vertex ML Metadata and Vertex AI services integration.|

Vertex AI Pipelines can be used to create different types of training pipelines; such as custom jobs, hyperparameter tuning jobs, and distributed training jobs. We can also use Vertex AI datasets (managed datasets) in the training pipeline. But regardless of these different types, creating a pipeline in Vertex AI, follow these steps:
- Setup environment on GCP: enable api, service account, cloud storage, provision Vertex AI Workbench
- Write the pipeline code in Python, using either the Kubeflow Pipelines or TFX DSL.
- Compile the pipeline definition to JSON format using the KFP or TFX library.
- Submit the compiled pipeline definition to the Vertex AI API to be executed immediately.

The rest of this article describes how to perform each of the previous steps.

## Cloud environment setup
Create or use an existing Google Cloud Project. Make sure that you are the owner of the project and that billing is enabled.

Enable the necessary APIs for the deployment, such as Kubernetes Engine API, Cloud Build API, and Container Registry API. For example, you can run the following command to enable the Kubernetes Engine API:

```bash
gcloud services enable container.googleapis.com
```

Install the Google Cloud SDK and the Kubeflow CLI on your development environment: local machine or [Vertex AI Pipelines Jupyter notebooks](https://cloud.google.com/vertex-ai/docs/pipelines/notebooks).

Configure your environment variables for your project ID, region, and pipeline root. For example, you can run the following commands to set your project ID, region, and pipeline root:

```bash
export PROJECT_ID=[YOUR_PROJECT_ID]
export REGION=[YOUR_REGION]
export PIPELINE_ROOT=gs://[YOUR_BUCKET_NAME]/pipeline_root
```

Create a Cloud Storage bucket to store your pipeline artifacts and outputs. For example, you can run the following command to create a bucket with the same name as your pipeline root:

```bash
gsutil mb -l ${REGION} -p ${PROJECT_ID} ${PIPELINE_ROOT}
```

Grant your team access to Kubeflow by assigning them the appropriate roles on the GCP console. For example, you can run the following command to grant the `roles/iap.httpsResourceAccessor` role to a user:

```bash
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
--member=user:${EMAIL} \
--role=roles/iap.httpsResourceAccessor
```

Install the `google_cloud_pipeline_components` library to be able to import and use pre-built components for Vertex AI services and features, such as datasets, models, endpoints, AutoML, custom training, batch prediction, online prediction, etc.

```bash
pip install google-cloud-pipeline-components
```

## Implementing pipelines

Vertex AI pipelines pre-built components are a set of predefined Kubeflow Pipelines components that are production quality, performant, and easy to use. These components allow you to interact with various Vertex AI services and features, such as datasets, models, endpoints, AutoML, custom training, batch prediction, online prediction, etc¹.

You can use these components in your pipeline function, which defines the steps and logic of your pipeline using the `@kfp.dsl.pipeline` decorator. You can import and use pre-built components from the `google_cloud_pipeline_components` library, which provides the `aiplatform` module that contains the components².

For example, you can use the `TabularDatasetCreateOp` component to create a tabular dataset from a CSV file, the `AutoMLTabularTrainingJobRunOp` component to train an AutoML tabular classification model on the dataset, and the `ModelDeployOp` component to deploy the model to an endpoint³.

You can find more details and examples of using pre-built components for interacting with Vertex AI services and features in your pipeline in the [Vertex AI documentation](^1^), the [Intro to Vertex Pipelines codelab](^4^), and the [google-cloud-pipeline-components SDK reference](^2^).


### With pre-built components

Here is a step by step example of defining and running a pipeline on Vertex AI:

First, you need to install the Kubeflow Pipelines SDK and the Google Cloud Pipeline Components SDK. You can use the following commands in a notebook or terminal:

```python
!pip install kfp google-cloud-pipeline-components
```

- Next, you need to import the necessary modules and set some variables for your project ID, region, and pipeline root. You can use the following code:

```python
import kfp
from google_cloud_pipeline_components import aiplatform as gcc_aip
from kfp.v2 import compiler
from kfp.v2.google.client import AIPlatformClient

PROJECT_ID = 'your-project-id' # Change to your project ID
REGION = 'us-central1' # Change to your region
PIPELINE_ROOT = 'gs://your-bucket-name/pipeline_root' # Change to your bucket name
```

- Then, you need to define your pipeline function using the `@kfp.dsl.pipeline` decorator. In this example, we will create a simple pipeline that creates a dataset from a CSV file, trains a custom Scikit-learn model on that dataset, and deploys the model to an endpoint. You can use the following code:

```python
@kfp.dsl.pipeline(name='vertex-ai-pipeline-example')
def pipeline(project: str = PROJECT_ID,
             region: str = REGION,
             api_endpoint: str = REGION + '-aiplatform.googleapis.com',
             pipeline_root: str = PIPELINE_ROOT,
             dataset_display_name: str = 'iris',
             dataset_gcs_uri: str = 'gs://cloud-samples-data/ai-platform/iris/iris.csv',
             model_display_name: str = 'iris-sklearn',
             endpoint_display_name: str = 'iris-endpoint',
             machine_type: str = 'n1-standard-4',
             replica_count: int = 1,
             deployed_model_display_name: str = 'iris-sklearn'):
    # Create a tabular dataset from a CSV file
    dataset_create_op = gcc_aip.TabularDatasetCreateOp(
        project=project,
        display_name=dataset_display_name,
        gcs_source=dataset_gcs_uri
    )

    # Train a custom Scikit-learn model on the dataset
    training_op = gcc_aip.CustomContainerTrainingJobRunOp(
        project=project,
        display_name=model_display_name,
        container_uri='gcr.io/cloud-aiplatform/training/scikit-learn-cpu.0-23:latest',
        model_serving_container_image_uri='gcr.io/cloud-aiplatform/prediction/scikit-learn-cpu.0-23:latest',
        staging_bucket=pipeline_root,
        training_script_path='training/trainer.py',
        requirements='training/requirements.txt',
        dataset=dataset_create_op.outputs['dataset'],
        model=dataset_create_op.outputs['model'],
        base_output_dir=pipeline_root,
        args=[
            '--learning_rate', '0.1',
            '--n_estimators', '150',
            '--max_depth', '5'
        ]
    )

    # Deploy the model to an endpoint
    endpoint_create_op = gcc_aip.EndpointCreateOp(
        project=project,
        display_name=endpoint_display_name
    )

    model_deploy_op = gcc_aip.ModelDeployOp(
        project=project,
        endpoint=endpoint_create_op.outputs['endpoint'],
        model=training_op.outputs['model'],
        deployed_model_display_name=deployed_model_display_name,
        machine_type=machine_type,
        replica_count=replica_count
    )
```

For more details and examples, you can refer to the [Vertex AI Pipelines documentation](https://cloud.google.com/vertex-ai/docs/pipelines), and the [All Vertex AI code samples](https://cloud.google.com/vertex-ai/docs/samples).

### With custom-built components

create a step in vertex pipeline that clone a git repository and read the content of each file in a pandas dataframe then upload the dataframe as parquet file to Google storage

To create a step in Vertex pipeline that clones a git repository and reads the content of each file in a pandas dataframe, then uploads the dataframe as a parquet file to Google storage, you can follow these steps:

- First, you need to create a custom container that can run your Python code. You can use the following Dockerfile as an example:

```dockerfile
# Use the official lightweight Python image.
# https://hub.docker.com/_/python
FROM python:3.9-slim

# Install git
RUN apt-get update && apt-get install -y git

# Install pip requirements
COPY requirements.txt .
RUN python -m pip install -r requirements.txt

# Copy local code to the container image.
ENV APP_HOME /app
WORKDIR $APP_HOME
COPY . ./

# Run the web service on container startup. Here we use the gunicorn
# webserver, with one worker process and 8 threads.
# For environments with multiple CPU cores, increase the number of workers
# to be equal to the cores available.
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 main:app
```

- Next, you need to write your Python code that performs the following tasks:
    - Clone the git repository using the `git` module
    - Read the content of each file in the repository using the `os` and `pandas` modules
    - Concatenate the dataframes into one big dataframe
    - Upload the dataframe as a parquet file to Google storage using the `gcsfs` and `pyarrow` modules

You can use the following main.py file as an example:

```python
import os
import git
import pandas as pd
import gcsfs
import pyarrow as pa
import pyarrow.parquet as pq

# Define the git repository URL and the destination folder
REPO_URL = 'https://github.com/google-research-datasets/natural-questions.git'
DEST_FOLDER = '/tmp/natural-questions'

# Clone the repository
git.Repo.clone_from(REPO_URL, DEST_FOLDER)

# Read the content of each file in the repository
dataframes = []
for root, dirs, files in os.walk(DEST_FOLDER):
    for file in files:
        if file.endswith('.jsonl'):
            # Read the JSONL file as a dataframe
            df = pd.read_json(os.path.join(root, file), lines=True)
            # Append the dataframe to the list
            dataframes.append(df)

# Concatenate the dataframes into one big dataframe
big_df = pd.concat(dataframes, ignore_index=True)

# Upload the dataframe as a parquet file to Google storage
# Create a GCS filesystem object
fs = gcsfs.GCSFileSystem(project='your-project-id')
# Create a parquet schema from the dataframe
schema = pa.Table.from_pandas(big_df).schema
# Write the dataframe to a parquet file in a GCS bucket
with fs.open('gs://your-bucket-name/data.parquet', 'wb') as f:
    pq.write_table(big_df, f, schema=schema, compression='snappy')
```

- Then, you need to create a requirements.txt file that lists the dependencies of your Python code. You can use the following file as an example:

```txt
Flask==2.0.2
gunicorn==20.1.0
gitpython==3.1.24
pandas==1.3.4
gcsfs==2021.11.0
pyarrow==6.0.0
```

- Finally, you need to build and push your custom container image to a Container Registry, and then use the `CustomContainerTrainingJobRunOp` component to create a pipeline step that runs your container on Vertex AI. You can use the following code as an example:

```python
import kfp
from google_cloud_pipeline_components import aiplatform as gcc_aip
from kfp.v2 import compiler
from kfp.v2.google.client import AIPlatformClient

PROJECT_ID = 'your-project-id' # Change to your project ID
REGION = 'us-central1' # Change to your region
PIPELINE_ROOT = 'gs://your-bucket-name/pipeline_root' # Change to your bucket name
CONTAINER_URI = 'gcr.io/your-project-id/your-container-name:latest' # Change to your container URI

@kfp.dsl.pipeline(name='vertex-ai-pipeline-git-example')
def pipeline(project: str = PROJECT_ID,
             region: str = REGION,
             api_endpoint: str = REGION + '-aiplatform.googleapis.com',
             pipeline_root: str = PIPELINE_ROOT):
    # Create a custom container training job that clones a git repository and reads the content of each file in a pandas dataframe, then uploads the dataframe as a parquet file to Google storage
    custom_container_op = gcc_aip.CustomContainerTrainingJobRunOp(
        project=project,
        display_name='git-example',
        container_uri=CONTAINER_URI,
        staging_bucket=pipeline_root,
        base_output_dir=pipeline_root
    )
```

### With Component specification
To pass the git repository as an input to the step, you can use the `inputValue` placeholder in your component specification. For example, you can define a parameter called `repo_url` in your component and use it as an argument for the `git clone` command in your container. You can use the following code as an example:

```yaml
name: Git Clone and Read
description: Clones a git repository and reads the content of each file in a pandas dataframe, then uploads the dataframe as a parquet file to Google storage
inputs:
- {name: repo_url, type: String, description: 'The URL of the git repository to clone'}
- {name: project, type: String, description: 'The project ID for the GCS bucket'}
- {name: bucket, type: String, description: 'The name of the GCS bucket to upload the parquet file'}
outputs:
- {name: gcs_path, type: String, description: 'The GCS path of the uploaded parquet file'}
implementation:
  container:
    image: gcr.io/your-project-id/your-container-name:latest
    args:
    - --repo_url
    - {inputValue: repo_url}
    - --project
    - {inputValue: project}
    - --bucket
    - {inputValue: bucket}
    - --gcs_path
    - {outputPath: gcs_path}
```

Then, you can use the `load_component_from_file` or `load_component_from_url` functions from the Kubeflow Pipelines SDK to load your component and use it in your pipeline. You can use the following code as an example:

```python
import kfp
from google_cloud_pipeline_components import aiplatform as gcc_aip
from kfp.v2 import compiler
from kfp.v2.google.client import AIPlatformClient

PROJECT_ID = 'your-project-id' # Change to your project ID
REGION = 'us-central1' # Change to your region
PIPELINE_ROOT = 'gs://your-bucket-name/pipeline_root' # Change to your bucket name
REPO_URL = 'https://github.com/google-research-datasets/natural-questions.git' # Change to your repo URL
BUCKET = 'your-bucket-name' # Change to your bucket name

# Load your custom component from a local file or a URL
git_clone_and_read_op = kfp.components.load_component_from_file('git_clone_and_read.yaml')
# git_clone_and_read_op = kfp.components.load_component_from_url('https://raw.githubusercontent.com/your-repo/your-component/git_clone_and_read.yaml')

@kfp.dsl.pipeline(name='vertex-ai-pipeline-git-example')
def pipeline(project: str = PROJECT_ID,
             region: str = REGION,
             api_endpoint: str = REGION + '-aiplatform.googleapis.com',
             pipeline_root: str = PIPELINE_ROOT):
    # Create a custom container training job that clones a git repository and reads the content of each file in a pandas dataframe, then uploads the dataframe as a parquet file to Google storage
    git_clone_and_read_op = git_clone_and_read_op(
        repo_url=REPO_URL,
        project=project,
        bucket=BUCKET
    )
```

## Compile and Submit to Vertex AI

- Finally, you need to compile and run your pipeline using the `compiler.Compiler` and `AIPlatformClient` classes. You can use the following code:



To submit Vertex AI pipelines from a Vertex notebook, you can use the Kubeflow Pipelines SDK v2 or the TFX SDK to write, compile, and run your pipeline code in Python. You can also use the `google_cloud_pipeline_components` library to use pre-built components for interacting with Vertex AI services and features¹.

Here are the general steps to submit Vertex AI pipelines from a Vertex notebook:

- Create or open a Vertex notebook instance in the [Cloud Console](^2^) or the [Vertex AI Workbench](^3^). You can choose any notebook environment that has the Vertex AI SDK and the Kubeflow Pipelines SDK v2 installed, such as TensorFlow Enterprise 2.6 or PyTorch 1.10.

Once you are done with the pipeline implementation, using either the Kubeflow Pipelines or TFX DSL. You can use the `@kfp.dsl.pipeline` decorator to define your pipeline function, which specifies the steps and logic of your pipeline. 

- Compile your pipeline definition to JSON format using the KFP or TFX library. You can use the `compiler.Compiler` class to compile your pipeline function to a JSON file that defines the pipeline specification. For example, you can use the following code to compile your pipeline function to a file named `pipeline.json`:

```python
from kfp.v2 import compiler

# Compile the pipeline to JSON
compiler.Compiler().compile(
    pipeline_func=pipeline, # your pipeline function
    package_path='pipeline.json' # your output file name
)
```

- Run your pipeline using the `AIPlatformClient` class from the Kubeflow Pipelines SDK v2. You need to create an `AIPlatformClient` object that connects to the Vertex AI API. You also need to specify a Cloud Storage bucket that serves as the pipeline root for your pipeline. You can use the `create_run_from_job_spec` method to submit your pipeline to Vertex AI and run it. For example, you can use the following code to run your pipeline:

```python
from kfp.v2.google.client import AIPlatformClient

# Initialize the client
api_client = AIPlatformClient(
    project_id=PROJECT_ID, # your project ID
    region=REGION # your region
)

# Run the pipeline
response = api_client.create_run_from_job_spec(
    'pipeline.json', # your pipeline definition file
    pipeline_root=PIPELINE_ROOT # your pipeline root bucket
)
```

- Monitor your pipeline run in the Vertex AI console or programmatically using the `get_job` and `list_jobs` methods of the `AIPlatformClient` class. You can also use TensorBoard and Vizier to visualize and optimize your pipeline results.

You can find more details and examples of submitting Vertex AI pipelines from a Vertex notebook in the [Vertex AI documentation](^1^), the [Intro to Vertex Pipelines codelab](^4^), and the [google-cloud-pipeline-components SDK reference](^5^).

## Component specification
A Kubeflow component specification file is a YAML file that describes the component for the Kubeflow Pipelines system¹. A component specification file has the following parts¹³⁴:
- Metadata: Name, description, and other metadata of the component.
- Interface: Input and output specifications of the component, such as name, type, default value, description, etc.
- Implementation: How to execute the component, given the input arguments. For container components, this includes the container image, command, and arguments. For graph components, this includes the subgraph definition.

A component specification file is used to share and reuse components across different pipelines and projects. You can write your own component specification file or use existing ones from the Kubeflow Pipelines SDK or other sources⁵..


provide an example of component specification

An example of a component specification is:

```yaml
name: Multiply
description: A simple component that multiplies two numbers
inputs:
- {name: x, type: Integer, description: 'The first number'}
- {name: y, type: Integer, description: 'The second number'}
outputs:
- {name: multiply, type: Integer, description: 'The multiply of the two numbers'}
implementation:
  container:
    image: python:3.9
    command: [
      python, -c,
      "import sys
       x = int(sys.argv[1])
       y = int(sys.argv[2])
       multiply = x * y
       print(multiply, file=open('/tmp/multiply.txt', 'w'))",
      {inputValue: x},
      {inputValue: y}
    ]
    outputPaths:
      multiply: /tmp/multiply.txt
```

This component specification defines a component named `Multiply` that takes two integers as inputs and produces one integer as output. The component's implementation uses a Python container image and runs a Python script that reads the input values from the command-line arguments, calculates the multiply, and writes the output value to a file. The component specification also maps the inputs and outputs to the command-line arguments and the output file path. You can learn more about the component specification from the [Kubeflow documentation](https://www.kubeflow.org/docs/components/pipelines/v1/sdk/component-development/) or the [Kubeflow Pipelines SDK](https://www.kubeflow.org/docs/components/pipelines/v1/reference/component-spec/).


## That's all folks

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
