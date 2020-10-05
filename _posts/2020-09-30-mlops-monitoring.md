---
layout: post
comments: true
title: Challenges of monitoring ML models in production
categories: ml
tags: [mlops, monitoring]
toc: true
img_excerpt: assets/2020/09/20200930-monitoring-dashboard-excerpt.png
---

![monitoring-dashboard]({{ "assets/2020/09/20200930-monitoring-dashboard.png" | absolute_url }}){: .center-image }



To ensure service continuity and a minimum SLA (Service Level Agreement), traditional applications are deployed along with a monitoring system. Such a system is used to log metrics like request frequency, latency, and server load to take actions like raising alerts in case the service is interrupted.

Similarly, as part of an MLOps paradigm, Machine Learning deployments need to be monitored to keep track of the model's health and to take actions when performance metrics are degraded. We should not lose track of the fact that trained models come with performance metrics on offline datasets which do not guarantee performance when it goes live.
Unfortunately, this task of monitoring models is very challenging as there is a lack of tools, systems, and even a common understanding among the MLOps community of what an ML monitoring system should look like.

However, there are tools that ML practitioners use during training that can be also used during model deployment, for instance, model performance metrics and model explainability techniques. But this is not enough as another dimension that needs to be monitored is the data itself that the model receives to generate predictions. Take as an example, a model which was trained on cat pictures but suddenly during deployment starts getting dog pictures (such problem is called Data drifting). Furthermore, the presence of outliers in the new data can significantly degrade the deployed model performance.

The following sections discuss key challenges of monitoring Machine Learning models in production.

## Performance metrics
Labelling the data can be challenging since it is usually a very manual task that requires domain knowledge (e.g. medical images labeling) and as a result time consuming and expensive.
But in case the labels can be made available (e.g. a timeseries forcasting task) it is still challenging to use them to calculate the model performance:
- **How to handle metrics calculation?** Labels have to be fed to a parallel system (e.g. a different endpoint) that that will calculate user-defined metrics, i.e. either standard ML metrics (e.g. accuracy) or domain/business specific ones.
- **How to keep Metrics synchronized?** Most metrics are stateful, i.e. the calculation requires previous values in addition to the current value, keeping the metrics synchronised at scale is challenging.
- **When should a metric be calculated?** some metrics are useful when calculated over the lifetime of the model deployment, others can be calculate at a given point in time.
- **What threshold to use for a metric?** to take actions on the calculated metrics (e.g. raise alert on metric deterioriation) theresholds need to be set and coming up with the right value to limit false alarms can be challenging and requires domain knowledge.

## Proxy metrics
Unfortunately, it is not always possible to monitor the model performance on a live environment as this requires access to labels which can be impractical due to its operational or financial cost. In this case, monitoring the statistical characteristics of the model's input and output data can be used instead as a proxy for monitoring the model performance.

### Outlier values
Generalization of ML models is a well known problem that causes the model to perform poorly on unseen data. Outliers in the input data is a serious problem and should be flaged as anomalies. Choosing the right outlier detector for a specific application depends on:
- The modality and dimensionality of the data
- The availability of labeled normal vs outlier data,

Furthermore, the choice of outlier detector has implications on how it will be deployed:
- An offline detector (pre-trained) can be deployed as a separate static ML model
- An online detector have to be updated continuously and thus deployed as a stateful service.

<div id="anomaly"></div>
<script>
data = [{
  line: {
    color: '#1f77b4', 
    width: 3
  }, 
  mode: 'lines', 
  name: 'Input', 
  type: 'scatter', 
  x: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40], 
  y: [0.93, 0.9382134853756061, 0.9426539845960847, 0.9394023371404081, 0.9480441459452381, 0.9639288026340922, 0.9804984381222791, 0.9897760094014064, 1.0076642073721527, 1.0062340961453495, 1.0119510459183751, 1.0164813326178772, 1.0238435907274863, 1.0151450606810821, 1.0137752248177383, 1.0085551543915938, 1.0230546373551948, 1.0338777585987373, 1.0253056411621033, 1.0376357061555095, 0.83, 1.033082955691834, 1.032686937569602, 1.0412471020600345, 1.0426756484304383, 1.0440424311179248, 1.0510682981409727, 1.04444353491015, 1.045603086477451, 1.0644834297515107, 1.0607535562914077, 1.077942278291159, 1.0683507827035812, 1.071691829211161, 1.0648428459088701, 1.0655326350032517, 1.0829343917176217, 1.081977464474998, 1.1010861953236781, 1.1179760053789751, 1.1165940506854968]
}];
layout = {
  title: 'Anomaly Detection', 
  xaxis: {
    type: 'linear', 
    range: [1, 40], 
    title: 'X', 
    autorange: true, 
    titlefont: {
      size: 18, 
      family: 'Courier New, monospace'
    }
  }, 
  yaxis: {
    type: 'linear', 
    range: [0.7058522389406562, 1.1888074601275322], 
    title: 'Y', 
    autorange: true, 
    titlefont: {
      size: 18, 
      family: 'Courier New, monospace'
    }
  }, 
  autosize: true, 
  annotations: [
    {
      x: 21, 
      y: 0.83, 
      ax: 50, 
      ay: 0, 
      font: {
        size: 16, 
        color: 'red', 
        family: 'Courier New, monospace'
      }, 
      text: 'Unexpected value', 
      xanchor: 'left', 
      yanchor: 'bottom', 
      arrowhead: 1, 
      showarrow: true
    }
  ]
};
Plotly.plot('anomaly', {
  data: data,
  layout: layout
});
</script>


### Distribution shift
In contrast to outliers that usually refer to individual instances, data drift or shift
detection uses statistical hypothesis test to detect when two samples are drawn from the same underlying distribution. In our case, the drift detector tries to identify when the  distribution of the input data to the deployed model starts to diverge from the training data making the model predictions unreliable. One useful application of this is to help decide when the model in production needs to be retrained again.

Drift detectors can be classied in one of the following classes:
- Covariate shift when the input data distribution `p(x)` changes while the conditional label distribution `p(y|x)` does not.
- Label shift when the label data distribution `p(y)` changes but the conditional `p(x|y)` does not.

In case where data is high dimensional (e.g. images) one could attempt a dimensionality reduction step before running the hypothesis test.

<div id="drift"></div>
<script>
var x1 = [-0.62377881, -0.43196073, -0.67344863,  0.44105778,  0.72179002,
         0.99275609, -0.48127841,  1.32850656,  1.82239131,  0.18526821,
         2.44954425, -0.25437907,  0.25647234, -0.31546968,  3.56280462,
        -0.82000195, -0.65506912,  0.03402699,  1.88811873, -1.32041787,
         0.1817063 ,  0.88655966,  0.33415247, -0.90132003, -0.03901121,
         0.71275626,  0.55156787, -0.11347053, -0.66490586, -0.3230691 ,
        -0.5095038 ,  0.89685236,  1.78619495, -0.83377115, -0.84906606,
        -1.16902611, -0.19215546,  0.09580733, -0.43044414,  0.90817288,
        -0.43309645,  1.96000649, -1.29845188, -0.46617614,  0.04311908,
         0.76552627,  0.10035865, -0.69652273, -0.09478376,  0.0321872 ,
        -0.63103333,  1.33117711, -0.57706113, -0.5568046 , -0.08029068,
        -0.94117893,  0.76431184,  1.13819163,  2.497312  , -0.39035797,
         0.24619723, -0.03989274,  1.21602674,  0.18085639, -0.74530304,
        -1.27561824, -1.09498061, -1.32717435,  0.71000751, -1.28415865,
        -1.04664204, -1.33135023, -1.01871093, -0.71098789, -0.83021936,
        -1.0782245 ,  0.26426042,  0.59476696, -1.35934946, -1.18904875,
         0.006204  , -0.53103716,  0.47556437, -0.15734439, -0.77329827,
         0.70004449, -0.29955822, -0.7862948 ,  0.89467001,  0.98971408,
        -1.04411047, -0.71761994,  1.66376504,  1.25952016, -1.30589665,
        -0.56646693, -0.62166506, -0.81933531,  2.08517309, -0.23387449
        ]
var x2 = [ 0.08894775,  0.15288711,  0.07239115,  0.44389328,  0.53747069,
         0.62779272,  0.13644788,  0.73970954,  0.90433779,  0.35863009,
         1.11338877,  0.212081  ,  0.3823648 ,  0.19171746,  1.48447556,
         0.02354004,  0.07851765,  0.30821635,  0.92624693, -0.14326527,
         0.35744279,  0.59239391,  0.40825818, -0.00356599,  0.28387029,
         0.53445944,  0.48072998,  0.25905051,  0.07523874,  0.18918432,
         0.12703942,  0.59582481,  0.89227234,  0.01895031,  0.013852  ,
        -0.09280135,  0.2328222 ,  0.3288098 ,  0.15339264,  0.59959832,
         0.15250854,  0.95020952, -0.13594327,  0.14148197,  0.31124705,
         0.55204945,  0.33032691,  0.06469978,  0.26527944,  0.30760309,
         0.08652958,  0.74059972,  0.10452031,  0.11127249,  0.27011046,
        -0.01685229,  0.55164464,  0.67627123,  1.12931136,  0.1667547 ,
         0.37893977,  0.28357644,  0.70221627,  0.35715949,  0.04843968,
        -0.12833206, -0.06811951, -0.14551743,  0.53354319, -0.13117886,
        -0.05200666, -0.14690939, -0.04269629,  0.05987806,  0.02013423,
        -0.06253414,  0.38496083,  0.49512968, -0.15624246, -0.09947556,
         0.29894202,  0.11986164,  0.45539548,  0.24442589,  0.03910793,
         0.53022218,  0.19702128,  0.03477575,  0.59509736,  0.62677872,
        -0.0511628 ,  0.05766737,  0.85146237,  0.71671407, -0.13842486,
         0.10805171,  0.08965234,  0.02376225,  0.99193172,  0.21891586
        ]
var data = [
  {
    histfunc: "count",
    x: x1,
    type: "histogram",
    name: "Expected distribution"
  },
  {
    histfunc: "count",
    x: x2,
    type: "histogram",
    name: "Actual distribution"
  }
]
var layout = {
  title:'Distribution shift',
}
Plotly.newPlot('drift', data, layout);
</script>