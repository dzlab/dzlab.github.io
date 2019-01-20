---
layout: post
comments: true
title: Deep Visual-Semantic Embedding Model with Keras
categories: dl
tags: [dl, cnn, nlp]
toc: true
#img_excerpt: assets/20190120-DeViSE_model.jpg
---

The image classification problem focus on classifying an image using a fixed set of labels. So they obviously do not scale and Furthermode, if a provided image has nothing to do with the original training set, the classifier will still attribute one or many of those labels to it. E.g. classifying a chicken image as digit five like in this [model](https://emiliendupont.github.io/2018/03/14/mnist-chicken/).


The Deep Visual-Semantic Embedding Model or [DeViSE](https://papers.nips.cc/paper/5204-devise-a-deep-visual-semantic-embedding-model), mixes words and images to identify objects using both labeled image data as well as semantic information. Thus creating completely new ways of classifying images that can scale to larger number of labels which are not available during training. It does so by embedding the labels from [ImageNet](http://www.image-net.org) into a [Word2Vec](https://en.wikipedia.org/wiki/Word2vec), thus levaraging the textual
data to learn semantic relationships between labels, and explicitly maps images into a rich semantic
embedding space.

![DeViSE_mDeViSE_vs_ImageNet1Kodel]({{ "/assets/20190120-DeViSE_vs_ImageNet1K.png" | absolute_url }}){: .center-image }

The DeViSE model (as depicted in the following picture) is trained in three phases. A skip-gram word2vec model trained on wikipedia for instance. Separately a softmax ImageNet classifier and finally the two are combined into the DeViSE model.

![DeViSE_model]({{ "/assets/20190120-DeViSE_model.png" | absolute_url }}){: .center-image }

In the remaining we will build DeViSE model in [Keras](https://keras.io) by using a pre-trained imagenet classifer (as described [here](https://dzlab.github.io/dl/2018/12/25/transfer-learning-keras/)), and a pre-trained wordnet embedding layer for English from Facebook's [FastText](https://fasttext.cc/docs/en/pretrained-vectors.html).


$$ loss(image, label) = \sum_{j \neq label} max[0, margin − \vec{t}_{label} M \vec{v} (image) + \vec{t}_{j} M \vec{v} (image)] $$

The loss function is defined as follows $$  {\displaystyle D_{C}(A,B)=1-S_{C}(A,B)} $$ where $$ {\displaystyle D_{C}} $$ is the Cosine Distance and $$ {\displaystyle S_{C}} $$ is the [Cosine Similarity](https://en.wikipedia.org/wiki/Cosine_similarity).


Full notebook can be found here - [link](https://github.com/dzlab/deepprojects/blob/master/classification/DeViSE_keras.ipynb)