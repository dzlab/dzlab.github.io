---
layout: post
comments: true
title: ML on the Edge with Tensorflow Lite
categories: tensorflow
tags: [lite, optimization]
toc: true
#img_excerpt: 
---

Deploying a complex ML model on an edge device can be interesting to reduce latency and improve user interaction (e.g. in the presence of network issues or when user is offline). It also addresses privacy concerns as users data will be processed to deliver an intelligent behavior locally without need them to be sent/stored to a remote server.

Tensorflow Lite is a framework for deploying tensorflow machine learning models into low resources devices (mobile and IoT). Tensorflow Lite has two main components:
* A converter that will help you converting existing models into a lightweight yet efficient model that can run very well on mobile devices
* An interpreter for each targeted platform (Android, IOS, IoT or local for testing) capable of running the converted model on embedded devices and perform inference.

To learn more about Tensorflow Lite and how to use it on mobile devices check [Udacity excellent course](https://www.udacity.com/course/intro-to-tensorflow-lite--ud190).

The rest of this tutorial will explore how to convert tensorflow models and test the generated model using Tensorflow Lite interpreter. The full notebook with more complete examples can be found [here](https://github.com/dzlab/deepprojects/blob/master/tensorflow/Tensorflow_Lite_conversion_examples.ipynb).

## Converting models into Tensorflow Lite
Say we have created a model, trained properly and we are happy with the accuracy (or anyother metric)
```python
# Create a model a train it
model = tf.keras.models.Sequential([/* model layers */])
model.compile(optimizer_name), loss=loss_function_name)
model.fit(X, y, epochs=...)
```
Now we want to use this model on a mobile device using Tensorflow Lite. We can choose any of the multiple choices for converting models, programmatically or using CLI (e.g. in a CI/CD pipeline) as follows:

### Converting SavedModel models
Tensorflow SavedModel is a storage format that helps saving the entire TensorFlow model (more generally any program) including weights for each layer and operations performed by the model. It is a perfect format for exchanging models, i.e. there is no need for sharing the original code in order to run the model.
Here is an example of how a SaveModel can be generated:

```python
# Save the model in the SavedModel format
tf.saved_model.save(model, output_dir)
```

Now once we have model in the SavedModel format we can convert it into a Tensorflow Lite model as follows:
```python
converter = tf.lite.TFLiteConverter.from_saved_model(output_dir)
tflite_model = converter.convert()
```

### Converting Keras models
Suppose we have same Keras model as the one create in the previous section, we can convert it into a Tensorflow Lite model without having to save it as follows:
```python
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
```

### Converting concrete functions
A concrete function is a format in which the model is saved as a graph of operations. Technically, a concrete function is a function decorated with [@tf.function](https://www.tensorflow.org/api_docs/python/tf/function). For example, we can wrap the Keras model and generate concrete function representation as follows:
```python
@tf.function
def concrete_model(x):
  return model(x)
input_shape = model.inputs[0].shape
input_dtype = model.inputs[0].dtype
concrete_func = concrete_model.get_concrete_function(tf.TensorSpec(input_shape, input_dtype))
```

Once we have the concrete function, we can convert it into a Tensorflow Lite format as follows:
```
converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
tflite_model = converter.convert()
```

### Converting from the CLI
Using the `tflite_convert` command which is part of tensorflow installation, we can convert models as follows:

1. Converting a SavedModel
```
$ tflite_convert --output-file=model.tflite --saved-model-dir=./output
```
2. Converting a Keras model
```
$ tflite_convert --output-file=model.tflite --keras_model_file=model.h5
```

Next optimizing the converted models