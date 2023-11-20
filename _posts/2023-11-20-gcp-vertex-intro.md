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

Vertex AI Pipelines can be used to create different types of training pipelines; such as custom jobs, hyperparameter tuning jobs, and distributed training jobs. We can also use Vertex AI datasets (managed datasets) in the training pipeline.

But regardless of these different types, creating a pipeline in Vertex AI, follow these steps:
- Setup environment on GCP: enable api, service account, cloud storage, provision Vertex AI Workbench
- Write the pipeline code in Python, using either the Kubeflow Pipelines or TFX DSL.
- Compile the pipeline definition to JSON format using the KFP or TFX library.
- Submit the compiled pipeline definition to the Vertex AI API to be executed immediately.

The rest of this article describes how to perform each of the previous steps.

## Cloud environment setup
You may first need to create or use an existing Google Cloud Project. Make sure that you are the owner of the project and that billing is enabled.

Then, enable the necessary APIs for the deployment, such as Kubernetes Engine API, Cloud Build API, and Container Registry API. For example, you can run the following command to enable the Kubernetes Engine API:

```bash
gcloud services enable container.googleapis.com
```

Install the Google Cloud SDK and the Kubeflow CLI on your development environment: local machine or [Vertex AI Pipelines Jupyter notebooks](https://cloud.google.com/vertex-ai/docs/pipelines/notebooks).You can create or open a Vertex notebook instance in the **Cloud Console** or the **Vertex AI Workbench**, and choose any notebook environment that has the Vertex AI SDK and the Kubeflow Pipelines SDK v2 installed, such as TensorFlow Enterprise 2.6 or PyTorch 1.10.

Then, configure your environment variables for your project ID, region, and pipeline root. For example, you can run the following commands to set your project ID, region, and pipeline root:

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
In this section, we will implement a Vertex AI pipeline that trains an AutoML model on the iris dataset. We will use the `TabularDatasetCreateOp` component to create a tabular dataset from a CSV file hosted on Google Storage, the `AutoMLTabularTrainingJobRunOp` component to train an AutoML tabular classification model on this dataset, and the `ModelDeployOp` component to deploy the model to an endpoint.


First, we import the necessary modules and set some variables for the project ID, region, and pipeline root.

```python
import kfp
from google_cloud_pipeline_components import aiplatform as gcc_aip

PROJECT_ID = 'your-project-id' # Change to your project ID
REGION = 'us-central1' # Change to your region
PIPELINE_ROOT = 'gs://your-bucket-name/pipeline_root' # Change to your bucket name
```

Then, we define the pipeline function using the `@kfp.dsl.pipeline` decorator. This function will define the steps and logic of the pipeline, using pre-built components from the `google_cloud_pipeline_components` library, use the outputs of one component as the inputs of another component, creating a dependency between them.

In our case, we will create a simple pipeline that creates a dataset from a CSV file, trains an AutoML model on that dataset, and deploys the model to an endpoint. 

```python
@kfp.dsl.pipeline(name='vertex-ai-pipeline-example')
def pipeline(project: str = PROJECT_ID,
             region: str = REGION,
             api_endpoint: str = REGION + '-aiplatform.googleapis.com',
             pipeline_root: str = PIPELINE_ROOT):

    # Create a tabular dataset from a CSV file
    dataset_create_op = gcc_aip.TabularDatasetCreateOp(
        project=project,
        display_name='iris',
        gcs_source='gs://cloud-samples-data/ai-platform/iris/iris.csv'
    )

    # Train an AutoML tabular classification model on the dataset
    training_op = gcc_aip.AutoMLTabularTrainingJobRunOp(
        project=project,
        display_name='automl-iris',
        optimization_prediction_type='classification',
        optimization_objective='minimize-log-loss',
        column_transformations=[
            {"numeric": {"column_name": "sepal_length"}},
            {"numeric": {"column_name": "sepal_width"}},
            {"numeric": {"column_name": "petal_length"}},
            {"numeric": {"column_name": "petal_width"}},
            {"categorical": {"column_name": "species"}}
        ],
        dataset=dataset_create_op.outputs['dataset'],
        target_column='species'
    )

    # Create a deployment endpoint
    endpoint_create_op = gcc_aip.EndpointCreateOp(
        project=project,
        display_name='iris-endpoint'
    )

    # Deploy the model to the previous endpoint
    model_deploy_op = gcc_aip.ModelDeployOp(
        project=project,
        endpoint=endpoint_create_op.outputs['endpoint'],
        model=training_op.outputs['model'],
        deployed_model_display_name='automl-iris',
        machine_type='n1-standard-4'
    )
```

You can find more details and examples of using pre-built components for interacting with Vertex AI services and features when implementing pipelines in the [Vertex AI Pipelines documentation](https://cloud.google.com/vertex-ai/docs/pipelines), and the [All Vertex AI code samples](https://cloud.google.com/vertex-ai/docs/samples).

## Compile and Submit to Vertex AI
After implementing the pipeline, we can compile the pipeline and then submit it to Vertex AI to run it.

Let's compile the pipeline definition from previous section to a JSON file that defines the pipeline specification. For example, the following code compile a pipeline function to a file named `pipeline.json`:

```python
from kfp.v2 import compiler

# Compile the pipeline to JSON
compiler.Compiler().compile(
    pipeline_func=pipeline, # your pipeline function
    package_path='pipeline.json' # your output file name
)
```

To submit a pipeline to Vertex AI and run it we need to create an instance of the `AIPlatformClient` class to connect to the Vertex AI API, then use the `create_run_from_job_spec` method to submit the pipeline as follows:

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

Once the pipeline is submitted successfully, we can monitor it in the Vertex AI console or programmatically using the `get_job` and `list_jobs` methods of the `AIPlatformClient` class. We can also use TensorBoard and Vizier to visualize and optimize the pipeline results.


## That's all folks
In this article we saw how easy it is to create ML training pipelines on GCP with Vertex AI pipelines and leaveraging off-the-shelf components to create an AutoML training job.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
