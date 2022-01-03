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

<center><img alt="intel analytics zoo" src='https://raw.githubusercontent.com/intel-analytics/analytics-zoo/master/docs/docs/Image/logo.jpg' width='200' height='200'></center>

[Analytics Zoo](https://github.com/intel-analytics/analytics-zoo) is an open source Deep Learning library. Along with [BigDL](https://bigdl-project.github.io/), it allows to train and run Deep Learning workloads on Spark and Ray. Furthermore, this library has a Keras API which make using it very similar to using plain Keras API.

This articles shows how to use the Keras API to train and evaluate a classification model on the [iris dataset](https://archive.ics.uci.edu/ml/datasets/iris). Furthermore, we will use TensorBoard to analyze training logs.

**1.** Add a dependency to Intel's Analytics Zoo library which will bring in the jvm deep learning library BigDL.

```scala
libraryDependencies += "com.intel.analytics.zoo" % "analytics-zoo-bigdl_0.12.1-spark_3.0.0" % "0.9.0",
```

**2.** create a SparkSession and initialize Analytics Zoo context

```scala
val spark = SparkSession.builder().appName("analytics-zoo-demo").master("local[*]").getOrCreate()
val sc = NNContext.initNNContext(spark.sparkContext.getConf)
```

**3.** Read the raw data (in this case a CSV file containing the Iris dataset) into a Spark DataFrame

```scala
val path = getClass.getClassLoader.getResource("iris.csv").toString

val df = spark.read.option("header", true).option("inferSchema", true).csv(path)
```

**4.** Create a training dataset from the raw DataFrame

**4.1.** Define a helper function to transform each row into a `Sample` instance with:
- a tensor for the raining features `"sepal_len", "sepal_wid", "petal_len", "petal_wid"` and
- another tensor for the label `class`.

```scala
def prepareDataset(df: DataFrame, labelColumn: String, featureColumns: Array[String]): RDD[Sample[Float]] = {
    val columns = trainDF.columns
    val labelIndex = columns.indexOf(labelColumn)
    val featureIndices = featureColumns.map(fc => df.columns.indexOf(fc))
    val dimInput = featureColumns.length
    df.rdd.map{row =>
      val features = featureIndices.map(row.getDouble(_).toFloat)
      val featureTensor = Tensor[Float](features, Array(dimInput))
      val labelTensor = Tensor[Float](1)
      labelTensor(Array(1)) = labels.indexOf(row.getString(labelIndex)) + 1
      Sample[Float](featureTensor, labelTensor)
    }
}
```

**4.2.** Apply the helper function on the training and validation datasets

```scala
val labels = Array("Iris-setosa", "Iris-versicolor", "Iris-virginica")
val labelCol = "class"
val featureCols = Array("sepal_len", "sepal_wid", "petal_len", "petal_wid")
val (trainDF, evalDF) = dataset.randomSplit(Array(0.8, 1 - 0.8), 31)
val trainRDD = prepareDatasetForFitting(trainDF, labelCol, featureCols)
val evalRDD = prepareDatasetForFitting(evalDF, labelCol, featureCols)
```

**5.** Create the model architecture by definining the list of layers and their respective activation functions.

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

**6.** Compile and initiate the model training

```scala
model.compile(
    optimizer = new SGD[Float](learningRate = 0.01),
    loss = CrossEntropyCriterion[Float]()
)
```

Set the directory used for storing training logs to be analyzed later with TensorBoard

```scala
model.setTensorBoard("logdir", "iris-example")
```

Now we can start the model training

```scala
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



**7.** Analyze training logs with TensorBoard

After the training finishes, TensorBoard logs will be availabile 
```
$ tree logdir/          
logdir/
└── iris-example
    └── train
        └── bigdl.tfevents.1641251780.dzlab-2.local

2 directories, 1 file
```

Make sure TensorBoard is available in your system or install it with

```
$ conda install -c conda-forge tensorboard
```

Now we can visualize the training logs

```
$ tensorboard --logdir=logdir/iris-example/  
TensorFlow installation not found - running with reduced feature set.

NOTE: Using experimental fast data loading logic. To disable, pass
    "--load_fast=false" and report issues on GitHub. More details:
    https://github.com/tensorflow/tensorboard/issues/4784

Serving TensorBoard on localhost; to expose to the network, use a proxy or pass --bind_all
TensorBoard 2.7.0 at http://localhost:6006/ (Press CTRL+C to quit)
```

Then, visit TensorBoard UI at http://localhost:6006/ 

<tb-webapp _nghost-htc-c144="" ng-version="12.2.1"><app-header _ngcontent-htc-c144="" _nghost-htc-c135=""><mat-toolbar _ngcontent-htc-c135="" class="mat-toolbar mat-toolbar-single-row"><span _ngcontent-htc-c135="" class="brand">TensorBoard</span><plugin-selector _ngcontent-htc-c135="" class="plugins"><plugin-selector-component _nghost-htc-c103=""><mat-tab-group _ngcontent-htc-c103="" animationduration="100ms" class="mat-tab-group active-plugin-list mat-primary"><mat-tab-header class="mat-tab-header"><div aria-hidden="true" mat-ripple="" class="mat-ripple mat-tab-header-pagination mat-tab-header-pagination-before mat-elevation-z4 mat-tab-header-pagination-disabled"><div class="mat-tab-header-pagination-chevron"></div></div><div class="mat-tab-label-container"><div role="tablist" class="mat-tab-list" style="transform: translateX(0px);"><div class="mat-tab-labels"><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-label-active ng-star-inserted" id="mat-tab-label-0-0" tabindex="0" aria-posinset="1" aria-setsize="15" aria-controls="mat-tab-content-0-0" aria-selected="true" aria-disabled="false"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="scalars"> scalars </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-disabled ng-star-inserted" id="mat-tab-label-0-1" aria-posinset="2" aria-setsize="15" aria-controls="mat-tab-content-0-1" aria-selected="false" aria-disabled="true"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="custom_scalars"> Custom Scalars </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-disabled ng-star-inserted" id="mat-tab-label-0-2" aria-posinset="3" aria-setsize="15" aria-controls="mat-tab-content-0-2" aria-selected="false" aria-disabled="true"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="images"> images </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-disabled ng-star-inserted" id="mat-tab-label-0-3" aria-posinset="4" aria-setsize="15" aria-controls="mat-tab-content-0-3" aria-selected="false" aria-disabled="true"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="audio"> audio </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-disabled ng-star-inserted" id="mat-tab-label-0-4" aria-posinset="5" aria-setsize="15" aria-controls="mat-tab-content-0-4" aria-selected="false" aria-disabled="true"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="debugger-v2"> Debugger V2 </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-disabled ng-star-inserted" id="mat-tab-label-0-5" aria-posinset="6" aria-setsize="15" aria-controls="mat-tab-content-0-5" aria-selected="false" aria-disabled="true"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="graphs"> graphs </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-disabled ng-star-inserted" id="mat-tab-label-0-6" aria-posinset="7" aria-setsize="15" aria-controls="mat-tab-content-0-6" aria-selected="false" aria-disabled="true"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="distributions"> distributions </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-disabled ng-star-inserted" id="mat-tab-label-0-7" aria-posinset="8" aria-setsize="15" aria-controls="mat-tab-content-0-7" aria-selected="false" aria-disabled="true"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="histograms"> histograms </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-disabled ng-star-inserted" id="mat-tab-label-0-8" aria-posinset="9" aria-setsize="15" aria-controls="mat-tab-content-0-8" aria-selected="false" aria-disabled="true"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="text"> text </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-disabled ng-star-inserted" id="mat-tab-label-0-9" aria-posinset="10" aria-setsize="15" aria-controls="mat-tab-content-0-9" aria-selected="false" aria-disabled="true"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="pr_curves"> PR Curves </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-disabled ng-star-inserted" id="mat-tab-label-0-10" aria-posinset="11" aria-setsize="15" aria-controls="mat-tab-content-0-10" aria-selected="false" aria-disabled="true"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="profile_redirect"> Profile </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-disabled ng-star-inserted" id="mat-tab-label-0-11" aria-posinset="12" aria-setsize="15" aria-controls="mat-tab-content-0-11" aria-selected="false" aria-disabled="true"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="hparams"> hparams </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-disabled ng-star-inserted" id="mat-tab-label-0-12" aria-posinset="13" aria-setsize="15" aria-controls="mat-tab-content-0-12" aria-selected="false" aria-disabled="true"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="mesh"> mesh </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator ng-star-inserted" id="mat-tab-label-0-13" tabindex="-1" aria-posinset="14" aria-setsize="15" aria-controls="mat-tab-content-0-13" aria-selected="false" aria-disabled="false"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="timeseries"> Time Series </span><!----><!----><!----></div></div><div role="tab" mattablabelwrapper="" mat-ripple="" cdkmonitorelementfocus="" class="mat-ripple mat-tab-label mat-focus-indicator mat-tab-disabled ng-star-inserted" id="mat-tab-label-0-14" aria-posinset="15" aria-setsize="15" aria-controls="mat-tab-content-0-14" aria-selected="false" aria-disabled="true"><div class="mat-tab-label-content"><span _ngcontent-htc-c103="" class="plugin-name ng-star-inserted" data-plugin-id="projector"> projector </span><!----><!----><!----></div></div><!----></div><mat-ink-bar class="mat-ink-bar" style="visibility: visible; left: 36px; width: 85px;"></mat-ink-bar></div></div><div aria-hidden="true" mat-ripple="" class="mat-ripple mat-tab-header-pagination mat-tab-header-pagination-after mat-elevation-z4 mat-tab-header-pagination-disabled"><div class="mat-tab-header-pagination-chevron"></div></div></mat-tab-header><div class="mat-tab-body-wrapper" style=""><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-3 mat-tab-body-active ng-star-inserted" id="mat-tab-content-0-0" aria-labelledby="mat-tab-label-0-0"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-3 ng-trigger ng-trigger-translateTab" style="transform: none;"><!----><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-4 ng-star-inserted" id="mat-tab-content-0-1" aria-labelledby="mat-tab-label-0-1"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-4 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-5 ng-star-inserted" id="mat-tab-content-0-2" aria-labelledby="mat-tab-label-0-2"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-5 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-6 ng-star-inserted" id="mat-tab-content-0-3" aria-labelledby="mat-tab-label-0-3"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-6 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-7 ng-star-inserted" id="mat-tab-content-0-4" aria-labelledby="mat-tab-label-0-4"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-7 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-8 ng-star-inserted" id="mat-tab-content-0-5" aria-labelledby="mat-tab-label-0-5"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-8 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-9 ng-star-inserted" id="mat-tab-content-0-6" aria-labelledby="mat-tab-label-0-6"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-9 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-10 ng-star-inserted" id="mat-tab-content-0-7" aria-labelledby="mat-tab-label-0-7"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-10 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-11 ng-star-inserted" id="mat-tab-content-0-8" aria-labelledby="mat-tab-label-0-8"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-11 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-12 ng-star-inserted" id="mat-tab-content-0-9" aria-labelledby="mat-tab-label-0-9"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-12 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-13 ng-star-inserted" id="mat-tab-content-0-10" aria-labelledby="mat-tab-label-0-10"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-13 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-14 ng-star-inserted" id="mat-tab-content-0-11" aria-labelledby="mat-tab-label-0-11"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-14 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-15 ng-star-inserted" id="mat-tab-content-0-12" aria-labelledby="mat-tab-label-0-12"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-15 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-16 ng-star-inserted" id="mat-tab-content-0-13" aria-labelledby="mat-tab-label-0-13"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-16 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><mat-tab-body role="tabpanel" class="mat-tab-body ng-tns-c47-17 ng-star-inserted" id="mat-tab-content-0-14" aria-labelledby="mat-tab-label-0-14"><div cdkscrollable="" class="mat-tab-body-content ng-tns-c47-17 ng-trigger ng-trigger-translateTab" style="transform: translate3d(100%, 0px, 0px); min-height: 1px;"><!----></div></mat-tab-body><!----></div></mat-tab-group><mat-form-field _ngcontent-htc-c103="" floatlabel="never" class="mat-form-field ng-tns-c65-1 mat-primary mat-form-field-type-mat-select mat-form-field-appearance-legacy mat-form-field-has-label mat-form-field-hide-placeholder ng-star-inserted"><div class="mat-form-field-wrapper ng-tns-c65-1"><div class="mat-form-field-flex ng-tns-c65-1"><!----><!----><div class="mat-form-field-infix ng-tns-c65-1"><mat-select _ngcontent-htc-c103="" role="combobox" aria-autocomplete="none" aria-haspopup="true" class="mat-select ng-tns-c102-2 ng-tns-c65-1 mat-select-empty ng-star-inserted" aria-labelledby="mat-form-field-label-1 mat-select-value-1" id="mat-select-0" tabindex="0" aria-expanded="false" aria-required="false" aria-disabled="false" aria-invalid="false"><div cdk-overlay-origin="" class="mat-select-trigger ng-tns-c102-2"><div class="mat-select-value ng-tns-c102-2" id="mat-select-value-1"><span class="mat-select-placeholder mat-select-min-line ng-tns-c102-2 ng-star-inserted"></span><!----><!----></div><div class="mat-select-arrow-wrapper ng-tns-c102-2"><div class="mat-select-arrow ng-tns-c102-2"></div></div></div><!----></mat-select><span class="mat-form-field-label-wrapper ng-tns-c65-1"><label class="mat-form-field-label ng-tns-c65-1 mat-empty mat-form-field-empty ng-star-inserted" id="mat-form-field-label-1" for="mat-select-0" aria-owns="mat-select-0"><!----><mat-label _ngcontent-htc-c103="" class="ng-tns-c65-1 ng-star-inserted">Inactive</mat-label><!----><!----></label><!----></span></div><!----></div><div class="mat-form-field-underline ng-tns-c65-1 ng-star-inserted"><span class="mat-form-field-ripple ng-tns-c65-1"></span></div><!----><div class="mat-form-field-subscript-wrapper ng-tns-c65-1"><!----><div class="mat-form-field-hint-wrapper ng-tns-c65-1 ng-trigger ng-trigger-transitionMessages ng-star-inserted" style="opacity: 1; transform: translateY(0%);"><!----><div class="mat-form-field-hint-spacer ng-tns-c65-1"></div></div><!----></div></div></mat-form-field><!----></plugin-selector-component></plugin-selector><tbdev-upload-button _ngcontent-htc-c135="" _nghost-htc-c116="" class="shown"><button _ngcontent-htc-c116="" mat-stroked-button="" class="mat-focus-indicator mat-stroked-button mat-button-base ng-star-inserted"><span class="mat-button-wrapper"><span _ngcontent-htc-c116="" class="button-contents"><mat-icon _ngcontent-htc-c116="" role="img" svgicon="info_outline_24px" class="mat-icon notranslate mat-icon-no-color" aria-hidden="true" data-mat-icon-type="svg" data-mat-icon-name="info_outline_24px"><svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%" viewBox="0 0 24 24" fit="" preserveAspectRatio="xMidYMid meet" focusable="false"><path d="M11 17h2v-6h-2v6zm1-15C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zM11 9h2V7h-2v2z"></path></svg></mat-icon> Upload </span></span><span matripple="" class="mat-ripple mat-button-ripple"></span><span class="mat-button-focus-overlay"></span></button><!----></tbdev-upload-button><app-header-dark-mode-toggle _ngcontent-htc-c135=""><app-header-dark-mode-toggle-component><button aria-haspopup="true" mat-icon-button="" aria-label="Menu for changing light or dark theme" class="mat-focus-indicator mat-menu-trigger mat-icon-button mat-button-base" title="Current mode: [Browser default]. Switch between browser default, light, or dark theme."><span class="mat-button-wrapper"><mat-icon role="img" svgicon="brightness_6_24px" class="mat-icon notranslate mat-icon-no-color ng-star-inserted" aria-hidden="true" data-mat-icon-type="svg" data-mat-icon-name="brightness_6_24px"><svg xmlns="http://www.w3.org/2000/svg" height="100%" viewBox="0 0 24 24" width="100%" fit="" preserveAspectRatio="xMidYMid meet" focusable="false"><path d="M0 0h24v24H0z" fill="none"></path><path d="M20 15.31L23.31 12 20 8.69V4h-4.69L12 .69 8.69 4H4v4.69L.69 12 4 15.31V20h4.69L12 23.31 15.31 20H20v-4.69zM12 18V6c3.31 0 6 2.69 6 6s-2.69 6-6 6z"></path></svg></mat-icon><!----><!----><!----></span><span matripple="" class="mat-ripple mat-button-ripple mat-button-ripple-round"></span><span class="mat-button-focus-overlay"></span></button><!----><mat-menu class="ng-tns-c120-0"><!----></mat-menu></app-header-dark-mode-toggle-component></app-header-dark-mode-toggle><app-header-reload _ngcontent-htc-c135="" _nghost-htc-c124=""><button _ngcontent-htc-c124="" mat-icon-button="" class="mat-focus-indicator reload-button mat-icon-button mat-button-base" title="Last Updated: Jan 3, 2022, 3:26:16 PM"><span class="mat-button-wrapper"><mat-icon _ngcontent-htc-c124="" role="img" svgicon="refresh_24px" class="mat-icon notranslate refresh-icon mat-icon-no-color" aria-hidden="true" data-mat-icon-type="svg" data-mat-icon-name="refresh_24px"><svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%" viewBox="0 0 24 24" fit="" preserveAspectRatio="xMidYMid meet" focusable="false"><path d="M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z"></path></svg></mat-icon></span><span matripple="" class="mat-ripple mat-button-ripple mat-button-ripple-round"></span><span class="mat-button-focus-overlay"></span></button></app-header-reload><settings-button _ngcontent-htc-c135=""><settings-button-component><button mat-icon-button="" class="mat-focus-indicator mat-icon-button mat-button-base"><span class="mat-button-wrapper"><mat-icon role="img" svgicon="settings_24px" class="mat-icon notranslate mat-icon-no-color" aria-hidden="true" data-mat-icon-type="svg" data-mat-icon-name="settings_24px"><svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%" viewBox="0 0 24 24" fit="" preserveAspectRatio="xMidYMid meet" focusable="false"><path d="M19.43 12.98c.04-.32.07-.64.07-.98s-.03-.66-.07-.98l2.11-1.65c.19-.15.24-.42.12-.64l-2-3.46c-.12-.22-.39-.3-.61-.22l-2.49 1c-.52-.4-1.08-.73-1.69-.98l-.38-2.65C14.46 2.18 14.25 2 14 2h-4c-.25 0-.46.18-.49.42l-.38 2.65c-.61.25-1.17.59-1.69.98l-2.49-1c-.23-.09-.49 0-.61.22l-2 3.46c-.13.22-.07.49.12.64l2.11 1.65c-.04.32-.07.65-.07.98s.03.66.07.98l-2.11 1.65c-.19.15-.24.42-.12.64l2 3.46c.12.22.39.3.61.22l2.49-1c.52.4 1.08.73 1.69.98l.38 2.65c.03.24.24.42.49.42h4c.25 0 .46-.18.49-.42l.38-2.65c.61-.25 1.17-.59 1.69-.98l2.49 1c.23.09.49 0 .61-.22l2-3.46c.12-.22.07-.49-.12-.64l-2.11-1.65zM12 15.5c-1.93 0-3.5-1.57-3.5-3.5s1.57-3.5 3.5-3.5 3.5 1.57 3.5 3.5-1.57 3.5-3.5 3.5z"></path></svg></mat-icon></span><span matripple="" class="mat-ripple mat-button-ripple mat-button-ripple-round"></span><span class="mat-button-focus-overlay"></span></button></settings-button-component></settings-button><a _ngcontent-htc-c135="" mat-icon-button="" href="https://github.com/tensorflow/tensorboard/blob/master/README.md" rel="noopener noreferrer" target="_blank" aria-label="Help" class="mat-focus-indicator readme mat-icon-button mat-button-base" tabindex="0" aria-disabled="false"><span class="mat-button-wrapper"><mat-icon _ngcontent-htc-c135="" role="img" svgicon="help_outline_24px" class="mat-icon notranslate mat-icon-no-color" aria-hidden="true" data-mat-icon-type="svg" data-mat-icon-name="help_outline_24px"><svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%" viewBox="0 0 24 24" fit="" preserveAspectRatio="xMidYMid meet" focusable="false"><path d="M11 18h2v-2h-2v2zm1-16C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm0-14c-2.21 0-4 1.79-4 4h2c0-1.1.9-2 2-2s2 .9 2 2c0 2-3 1.75-3 5h2c0-2.25 3-2.5 3-5 0-2.21-1.79-4-4-4z"></path></svg></mat-icon></span><span matripple="" class="mat-ripple mat-button-ripple mat-button-ripple-round"></span><span class="mat-button-focus-overlay"></span></a></mat-toolbar></app-header><main _ngcontent-htc-c144=""><router-outlet _ngcontent-htc-c144=""><router-outlet-component><tensorboard-wrapper-component _nghost-htc-c343="" class="ng-star-inserted"><plugins _ngcontent-htc-c343="" class="plugins" _nghost-htc-c341=""><plugins-component _ngcontent-htc-c341="" _nghost-htc-c340=""><div _ngcontent-htc-c340="" class="plugins is-first-party-plugin"><!----><tf-scalar-dashboard></tf-scalar-dashboard></div><!----><!----><!----></plugins-component></plugins><reloader _ngcontent-htc-c343=""></reloader></tensorboard-wrapper-component><!----></router-outlet-component></router-outlet></main><alert-snackbar _ngcontent-htc-c144=""></alert-snackbar><hash-storage _ngcontent-htc-c144="" _nghost-htc-c139=""><hash-storage-component _ngcontent-htc-c139=""></hash-storage-component></hash-storage><page-title _ngcontent-htc-c144="" _nghost-htc-c141=""><page-title-component _ngcontent-htc-c141=""></page-title-component></page-title><settings-polymer-interop _ngcontent-htc-c144=""></settings-polymer-interop><dark-mode-supporter _ngcontent-htc-c144="" _nghost-htc-c143=""></dark-mode-supporter></tb-webapp>

**8.** Evaluate the model against a hold up dataset

```scala
val evalResult = model.evaluate(evalRDD, 8)
val evalMetrics = evalResult.map{case (result: ValidationResult, method: ValidationMethod[Float]) =>
    (method.toString(), result.result()._1.toDouble)
}.toMap
```

Printing the evaluation metrics with `println(evalMetrics)` will return something like `Map(Loss -> 1.0945806503295898)`.