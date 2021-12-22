---
layout: post
comments: true
title: DeepLearning on Spark with Analytics Zoo and BigDL
excerpt: Learn how to train deep learning models on Apache Spark using Intel's Analytics Zoo and BigDL.
categories: dl
tags: [deeplearning,spark,scala]
toc: true
img_excerpt:
---

Add a dependency to Intel's Analytics Zoo library which will bring in the jvm deep learning library BigDL.
```scala
libraryDependencies += "com.intel.analytics.zoo" % "analytics-zoo-bigdl_0.12.1-spark_3.0.0" % "0.9.0",
```

Create a SparkSession and initialize Analytics Zoo context
```scala
val spark = SparkSession.builder().appName("analytics-zoo-demo").master("local[*]").getOrCreate()
val sc = NNContext.initNNContext(spark.sparkContext.getConf)
```

Read the raw data (in this case a CSV file containing the Iris dataset) into a Spark DataFrame
```scala
val path = getClass.getClassLoader.getResource("iris.csv").toString

val df = spark.read.option("header", true).option("inferSchema", true).csv(path)
```

Create a training dataset from the raw DataFrame, this step consists of transforming each row into a `Sample` instance with:
- a tensor for the raining features `"sepal_len", "sepal_wid", "petal_len", "petal_wid"` and
- another tensor for the label `class`.

```scala
val labels = Array("Iris-setosa", "Iris-versicolor", "Iris-virginica")
val labelCol = "class"
val labelIndex = columns.indexOf("class")
val featureCols = Array("sepal_len", "sepal_wid", "petal_len", "petal_wid")
val featureIndexes = featureCols.map(columns.indexOf)
val trainDS = df.rdd.map{row =>
    val features = featureIndexes.map(row.getDouble(_).toFloat)
    val featureTensor = Tensor[Float](features, Array(dimInput))
    val labelTensor = Tensor[Float](1)
    labelTensor(Array(1)) = labels.indexOf(row.getString(labelIndex)) + 1
    Sample[Float](featureTensor, labelTensor)
}
```

Create the model architecture by definining the list of layers and their respective activation functions.
```
val dimInput = 4
val dimOutput = 3
val nHidden = 100
val model = Sequential[Float]()
model.add(Dense[Float](nHidden, activation = "relu", inputShape = Shape(dimInput)).setName("fc_1"))
model.add(Dense[Float](nHidden, activation = "relu").setName("fc_2"))
model.add(Dense[Float](dimOutput, activation = "softmax").setName("fc_3"))
```

> Note: we define the shape of the input only for the first layer, BigDL will infer the input shape for the reamining layers.

Prining the model with `model.summary()` gives something like this:
```
Model Summary:
------------------------------------------------------------------------------------------------------------------------
Layer (type)                            Output Shape              Param #       Connected to                          
========================================================================================================================
Inputeac325c7 (Input)                   (None, 4)                 0                                                   
________________________________________________________________________________________________________________________
fc_1 (Dense)                            (None, 100)               500           Inputeac325c7                         
________________________________________________________________________________________________________________________
fc_2 (Dense)                            (None, 100)               10100         fc_1                                  
________________________________________________________________________________________________________________________
fc_3 (Dense)                            (None, 3)                 303           fc_2                                  
________________________________________________________________________________________________________________________
Total params: 10,903
Trainable params: 10,903
Non-trainable params: 0
------------------------------------------------------------------------------------------------------------------------
```

Compile and initiate the model training
```scala
model.compile(
    optimizer = new SGD[Float](learningRate = 0.01),
    loss = SoftmaxWithCriterion[Float]()
)
model.fit(data, batchSize = batchSize, nbEpoch = maxEpoch)
```

During training the library will output something like this
```
2021-12-22T09:43:56.136-0800 level=INFO thread=main logger=com.intel.analytics.bigdl.optim.DistriOptimizer$
[Epoch 10 96/150][Iteration 48][Wall Clock 2.051005411s] Trained 32.0 records in 0.026512474 seconds. Throughput is 1206.979 records/second. Loss is 1.0808454. Sequential908171a5's hyper parameters: Current learning rate is 0.01. Current dampening is 1.7976931348623157E308.  
2021-12-22T09:43:56.169-0800 level=INFO thread=main logger=com.intel.analytics.bigdl.optim.DistriOptimizer$
[Epoch 10 128/150][Iteration 49][Wall Clock 2.083434694s] Trained 32.0 records in 0.032429283 seconds. Throughput is 986.7625 records/second. Loss is 1.0327523. Sequential908171a5's hyper parameters: Current learning rate is 0.01. Current dampening is 1.7976931348623157E308.  
2021-12-22T09:43:56.201-0800 level=INFO thread=main logger=com.intel.analytics.bigdl.optim.DistriOptimizer$
[Epoch 10 160/150][Iteration 50][Wall Clock 2.115638134s] Trained 32.0 records in 0.03220344 seconds. Throughput is 993.6827 records/second. Loss is 1.0637572. Sequential908171a5's hyper parameters: Current learning rate is 0.01. Current dampening is 1.7976931348623157E308.  
2021-12-22T09:43:56.202-0800 level=INFO thread=main logger=com.intel.analytics.bigdl.optim.DistriOptimizer$
[Epoch 10 160/150][Iteration 50][Wall Clock 2.115638134s] Epoch finished. Wall clock time is 2119.552539 ms
```