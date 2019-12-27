---
layout: post
comments: true
title: Timeseries Classification - Algorithms Review
categories: timeseries
---

Timeseris classification problems can be approached through a DL and non-DL approaches. Wether one approaches works better than the other may depend on the problem. Most non-DL state-of-the-art algorithms do not scale to large time series datasets however it is still needs to be confirmed with Proximity Forest and Rotation Forest.

Within DL there are 3 main approaches:

- Recurrent Neural Networks (RNN) like LSTM or GRU
- Convolutional Neural Networks (CNN)
- Hybrid models (combines RNN with CNN)

RNN are the ones been classically used for Timeseries problems, but in the last few years CNNs and Hybrid models started showing better performance. Here are some of the approaches I consider more interesting:

**RNN**
- Plain/ stacked LSTM / GRU
- Dilated Recurrent Neural Networks (Dilated RNN) (S. Chang, NIPs 2017) - [paper](https://arxiv.org/abs/1710.02224) [code](https://github.com/code-terminator/DilatedRNN)

**CNN**
1. Transfer learning applied to time series images (ts —> image —> resnet):

    1.1. Single image: 1-3 channel images (an encoder per channel) in a single resnet, [notebook](https://github.com/dzlab/deepprojects/blob/master/timeseries/Timeseries_Earthquakes.ipynb)

    1.2. Multi-image: 1-3 channel images (an encoder per channel) in parallel resnets [notebook]()

2. Training from scratch:

    2.1. Tiled Convolutional Neural Networks: Encoding Time Series as Images for Visual Inspection and Classification Using Tiled Convolutional Neural Networks (Z. Wang, 2015) [paper](https://aaai.org/ocs/index.php/WS/AAAIW15/paper/viewFile/10179/10251) [code](https://github.com/cauchyturing/Imaging-time-series-to-improve-classification-and-imputation)

    2.2. Temporal convolutional network (TCNs): An Empirical Evaluation of Generic Convolutional and Recurrent Networks for Sequence Modeling 1, (S. Bai, 2018), [paper](https://arxiv.org/abs/1803.01271) [code](https://github.com/locuslab/TCN)

    2.3. TrellisNet (modified TCN): Trellis Networks for Sequence Modeling (S. Bai, 2018), [paper](https://arxiv.org/abs/1810.06682) [code](https://github.com/locuslab/trellisnet)

**Hybrid models**

1. DeepConvLSTM: Deep Convolutional and LSTM Recurrent Neural Networks for Multimodal Wearable Activity Recognition (Ordoñez, 2016) [paper](https://www.mdpi.com/1424-8220/16/1/115/pdf) [code](https://scrutinizer-ci.com/g/NLeSC/mcfly/inspections/b8ffce89-d59a-4d05-a6c2-3bc6831ba9c1/code-structure/py-function/generate_DeepConvLSTM_model?expandCoverage=1)

2. LSTM Fully Convolutional Network (Temporal convolutions + LSTM in parallel):

    2.1. LSTM Fully Convolutional Networks for Time Series Classification 1 (F. Karim, 2017), current state of the art in may UCR univariate datasets, [paper](https://arxiv.org/abs/1709.05206) [code](https://github.com/houshd/LSTM-FCN)

    2.2. Multivariate LSTM-FCNs for Time Series Classification 1 (F. Karim, 2018), current state of the art in may UCR multivariate datasets, [paper](https://arxiv.org/abs/1801.04503) [code](https://github.com/titu1994/MLSTM-FCN)

### Univariate Timeseries Classification

Interesting approaches to consider (details in this github repo [https://github.com/hfawaz/dl-4-tsc])

1. NN dynamic time warping with a warping window set through cross-validation (DTW) has been extremely difficult to beat for over a decade, but it’s no longer considered state of the art.

SOTA  algorithms:

1. HIVE-COTE: current state of the art, but hugely computationally intensive. It combines predictions of 35 individual classifiers built on four representations of the data. Impractical in many problems. The HIVE version uses a hierarchical vote.
2. Resnet: same performance as COTE but much faster [python code](https://github.com/hfawaz/dl-4-tsc).

Other algorithms:
1. Shapelet Transform (ST): extracts discriminative subsequences (shapelets) and builds a new representation of the time series that is fed to an ensemble of 8 classifiers. While it is considered a state-of-the-art classifier, it has little potential to scale to large datasets given its training complexity. [python code](https://tslearn.readthedocs.io/en/latest/index.html)
2. BOSS (Bag-of-SFA-Symbols): forms a discriminative bag of words by discretizing the TS using a Discrete Fourier Transform and then building a nearest neighbor classifier with a bespoke distance measure. It is of limited use on large data sets as it has a high training complexity. The authors produced a similar approach with improved scalability, the BOSS in Vector Space (BOSS-VS). The same authors recently proposed WEASEL, which improves on the computation time of BOSS and on the accuracy of BOSS-VS, but has a very high memory complexity (it doesn’t scale beyond 10k TS) [python code](https://pyts.readthedocs.io/en/latest/index.html)
3. Proximity Forest (PF): new algorithm presented in Aug 2018. It is similar to Random Forest but replaces the attribute-based splitting criteria by a random similarity measure [java code](https://github.com/fpetitjean/ProximityForest). I don’t think there is any python code yet.
4. Rotation Forest (RotF): an algorithm that has recently been used with very good results in TSC. An early version (not fully optimized) [python code](http://www.timeseriesclassification.com/RotationForest/RotationForestClassifier_py.py).
5. Fully Convolutional Network (FCN): [python code](https://github.com/hfawaz/dl-4-tsc)
6. Encoder: whose architecture is inspired by FCN with a main difference where the GAP layer is replaced with an attention layer [python code](https://github.com/hfawaz/dl-4-tsc)

### Multivariate Timeseries Classification
The previous studies are inconclusive as to best algorithms to use in multivariate TS due to the small number of datasets used. However, FCN, Encoder, and Resnet also seem to work well.

### Libraries
1. [pyts](https://johannfaouzi.github.io/pyts/) a Python package for time series transformation and classification.
2. [cesium](https://github.com/cesium-ml/cesium) an open source library that allows users to extract features from raw time series data - [list](http://cesium-ml.org/docs/feature_table.html), build machine learning models from these features, and generate predictions for new data.
An example illustrating the power of this library - [Epilepsy Detection Using EEG Data 4](http://cesium-ml.org/docs/auto_examples/plot_EEG_Example.html#sphx-glr-auto-examples-plot-eeg-example-py).

### References
- The Great Time Series Classification Bake Off: An Experimental Evaluation of Recently Proposed Algorithms. Extended Version (Bagnall, 2016) [paper](https://arxiv.org/abs/1602.01711)
- Deep Learning for Time-Series Analysis (Gamboa, 2017) [paper](https://arxiv.org/abs/1701.01887)
- Deep learning for time series classification: a review (Fawaz, 2018) [paper](https://arxiv.org/abs/1809.04356) [code](https://github.com/hfawaz/dl-4-tsc)
- Proximity Forest: An effective and scalable distance-based classifier for time series (Lucas, 2018) [paper](https://arxiv.org/abs/1808.10594)
- Is rotation forest the best classifier for problems with continuous features? (Bagnall, 2018) [paper](https://arxiv.org/abs/1809.06705)

{% include disqus.html %}