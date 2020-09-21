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

## Using local files

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
from tfx.utils.dsl_utils import external_input

examples = external_input('tfrecord_data')
example_gen = ImportExampleGen(input=examples)

context.run(example_gen)
```