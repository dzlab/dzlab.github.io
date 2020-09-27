---
layout: post
comments: true
title: Data Ingestion with TensorFlow eXtended (TFX)
categories: ml
tags: [tensorflow, tfx]
toc: true
img_excerpt:
---

![tfx-components]({{ "assets/2020/09/20200913-tfx-components.png" | absolute_url }}){: .center-image }


The first step in a ML pipeline is data ingestion which consists of reading data from raw format and formatting it into a binary format suitable for ML (e.g. [TFRecord]({{ "dltips/en/tensorflow/tfrecord/" | absolute_url }})).
TFX provides a standard component called `ExampleGen` which is responsible for generating training examples from different data sources. This article will explain usage of this component in different scenarios:
- How to write data in TFRecords (the default data format for TensorFlow)
- How to split data into multiple subsets (e.g. training and evaluation)
- How to merge multiple subsets of data (e.g. hourly data) into one concise dataset
- How to deal with different data types (tabular, text and images)

For an overview of TFX standard components read this [post]({{ "ml/2020/09/08/tfx-pipelines/" | absolute_url }}).


To be able to test the code snippets in the rest of this article, make sure TFX is installed (simply `pip install tfx`) and a runtime context is available. TFX provides the `InteractiveContext` class to use when running a TFX component (or pipeline) interactively.
```python
from tfx.orchestration.experimental.interactive.interactive_context import InteractiveContext
context = InteractiveContext(
  pipeline_name='mypipeline',
  pipeline_root='.'
  )
```

## Using local data

### Generating TFRecord from CSV files
The basic example of using the `ExampleGen` component to generate TFRecords is with local CSV files as inputs:
```python
from tfx.components import CsvExampleGen
from tfx.utils import dsl_utils

examples = dsl_utils.external_input('data')
example_gen = CsvExampleGen(input=examples, instance_name='ingestion')

context.run(example_gen)
```
After the component is run successfully, an artifact representing metadata about the run is generated in addition to the TFRecords. We can inspect this artifact as follows:

```python
for artifact in example_gen.outputs['examples'].get():
  print(artifact)
```
An example output would look like the following example. Among the metadata, notice the notice pipeline name, the `eval` and `train` splits. Also, among the metadata is the fingerprint of the original raw data which can be very useful when inspecting what data was given to the pipeline:
```
Artifact(artifact: id: 3
type_id: 5
uri: "./CsvExampleGen.ingestion/examples/3"
properties {
  key: "split_names"
  value {
    string_value: "[\"train\", \"eval\"]"
  }
}
custom_properties {
  key: "input_fingerprint"
  value {
    string_value: "split:single_split,num_files:1,total_bytes:150828752,xor_checksum:1568937884,sum_checksum:1568937884"
  }
}
custom_properties {
  key: "name"
  value {
    string_value: "examples"
  }
}
custom_properties {
  key: "payload_format"
  value {
    string_value: "FORMAT_TF_EXAMPLE"
  }
}
custom_properties {
  key: "pipeline_name"
  value {
    string_value: "mypipeline"
  }
}
custom_properties {
  key: "producer_component"
  value {
    string_value: "CsvExampleGen.ingestion"
  }
}
custom_properties {
  key: "span"
  value {
    string_value: "0"
  }
}
custom_properties {
  key: "state"
  value {
    string_value: "published"
  }
}
, artifact_type: id: 5
name: "Examples"
properties {
  key: "span"
  value: INT
}
properties {
  key: "split_names"
  value: STRING
}
properties {
  key: "version"
  value: INT
}
)
```

On disk the resulting TFRecods data would have a structure that looks like this (notice the `eval` and `train` splits):
```
./CsvExampleGen.ingestion/
└── examples
    └── 1
        ├── eval
        │   └── data_tfrecord-00000-of-00001.gz
        └── train
            └── data_tfrecord-00000-of-00001.gz

4 directories, 2 files
```

Note: by default the root folder of the output TFRecords is `CsvExampleGen` if the instance name of the component (i.e. the `instance_name` parameter) is not set.

### Generating TFRecord from binary files
With TFX, we can generate TFRecord from binary serialized data using the generic `FileBasedExampleGen` class. This is done by overriding the component's `executor_class` with the right implementation that can ingest the raw data.

For example, to generate TFRecords from a Parquet dataset:
```python
# Write some Parquet formatted data for testing
import pyarrow as pa
import pyarrow.parquet as pq
df = pd.read_csv('data/creditcard.csv')
table = pa.Table.from_pandas(df)
pq.write_table(table, 'parquet_data/creditcard.parquet')

# Import generic file loader component and Parquet-specific executor
from tfx.components import FileBasedExampleGen
from tfx.components.example_gen.custom_executors import parquet_executor
from tfx.components.base.executor_spec import ExecutorClassSpec
from tfx.utils.dsl_utils import external_input

examples = external_input('parquet_data/')
executor_spec = ExecutorClassSpec(parquet_executor.Executor)
example_gen = FileBasedExampleGen(input_base=examples, custom_executor_spec=executor_spec)

context.run(example_gen)
```

Similarly, to generate TFRecords from an Avro dataset:
```python
# Write some AVRO formatted data for testing
import pandavro as pdx

df = pd.read_csv('data/creditcard.csv')
pdx.to_avro('avro_data/creditcard.avro', df)

# Import generic file loader component and Avro-specific executor
from tfx.components import FileBasedExampleGen
from tfx.components.example_gen.custom_executors import avro_executor
from tfx.utils.dsl_utils import external_input

examples = external_input('avro_data/')
executor_spec = ExecutorClassSpec(avro_executor.Executor)
example_gen = FileBasedExampleGen(input=examples, custom_executor_spec=executor_spec)

context.run(example_gen)
```

### Generating TFRecord from TFRecord files
TFX also let us ingest existing TFRecords (e.g. previously serialised images or text dataset as `tf.Example`) into a pipeline using the `ImportExampleGen` component without a need for conversion.

This can be achieved as follows:

```python
from tfx.components import ImportExampleGen
from tfx.utils import dsl_utils

examples = dsl_utils.external_input('tfrecord_data')
example_gen = ImportExampleGen(input=examples)

context.run(example_gen)
```

## Using remote data

### Generating TFRecord from cloud storage
In addition to reading local files of differnet format, the `ExampleGen` component can be used to read files stored on a cloud storage service (e.g. AWS or GCP).

```python
# read from Google storage
examples = dsl_utils.external_input("gs://bucket/path/to/data")
example_gen = CsvExampleGen(input=examples)

# read from AWS S3
examples = dsl_utils.external_input("s3://bucket/path/to/data")
example_gen = CsvExampleGen(input=examples)
```

Note: to access a private bucket valid credentials of the cloud provider are required.
For instance, to access private bucket on GCP you can set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable to the location of GCP account credential file (see [documentation](https://cloud.google.com/docs/authentication/getting-started)).

### Generating TFRecord from databases
The `ExampleGen` component has specific implementations for reading from files, currently only BigQuery through and Presto db are supported.

For generating TFRecord examples from Big Query use `BigQueryExampleGen` component as follows (for testing try [public datasets](https://console.cloud.google.com/marketplace/browse?filter=solution-type:dataset))

```python
from tfx.extensions.google_cloud_big_query.example_gen.component import BigQueryExampleGen

query = "SELECT * FROM <project_id>.<database>.<table_name>"
example_gen = BigQueryExampleGen(query=query)
```
Note: you will need to set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable.


Similarly, to read from a Presto database use `PrestoExampleGen` as follows
```python
# Import PrestoExampleGen and config class PrestoConnConfig
from tfx.examples.custom_components.presto_example_gen.proto.presto_config_pb2 import PrestoConnConfig
from tfx.examples.custom_components.presto_example_gen.presto_component.component import PrestoExampleGen

# Create a config object with Presto DB connection information
presto_config = PrestoConnConfig(host='localhost', port=8080)
# Create an example generator for a query
query = "SELECT * FROM <table_name>"
example_gen = PrestoExampleGen(presto_config, query=query)
```