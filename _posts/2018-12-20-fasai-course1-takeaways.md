---
layout: post
comments: true
title: fastai's Practical Deep Learning For Coders, Part 1
categories: dl
tags: [dl, cnn, rnn, nlp]
toc: true
#img_excerpt: assets/20181220-transfer-learning.jpg
---

I recently completed Part 1 of [Jeremy Howard](https://twitter.com/jeremyphoward)'s Practical Deep Learning For Coders. The course span over the course of 7 weeks from October to December, one course a week. All what's needed to join the course is math background of high-school level, a computer, network connectivity and access to a GPU machine, that's it! The course videos are recorded during the [in-person class at the Data Institute at USF](https://www.usfca.edu/data-institute/certificates/deep-learning-part-one), and freely available on youtube.

The following is an attempt to share my takeaways from the lessons.

> **Note** Expect to have to watch the video lessons over and over to fully understand the materials.

![do_deep_learning]({{ "/assets/20181220-do-deep-learning.jpg" | absolute_url }}){: .center-image }

What's very unique about this course is the focus on the practical side of the learning experince. Right from the very few moments of the course, you will see Deep Learning code, at first you won't understand what's it doing, you will not get it unless you're a Deep Learning expert. But you will be impressed how insanely is it simple to write Deep Learning code to solve problems seconds before the course you would have no idea how they can be solve, yet you will learn how to take that same code and re-apply it to sove a different problem.

> **Protip**: take as mush notes as you can while watching the video lessons, especially when Jeremy says 'here is the trick' or the other activation word 'homework'.



The other very impressive thing about this course is the [discussion forum](http://forums.fast.ai/) that gathers all the student in one place. Everyone is engaged, very responsive, you should definitely check it. You will find study groups that you could join in your city, examples of other student works that could inspire you. You will find help to get started with the [fastai library](http://docs.fast.ai), to setup your work environemnt in major Cloud providers or answers to any question you could have.

This is an overview of the course:

> Here is some nicely writing [lecture notes](https://github.com/hiromis/notes), kindly shared by [Hiromi Suenaga](https://twitter.com/hiromi_suenaga) one of the course students.

#### Lesson 1
Right from first few seconds of the course Jeremy tries to convince you that you can do Deep Learning. Then jumps on a notebook where he would walk you through the cells, run them and explain what is doing and how you could play with it. By the end of the lesson you will be able to build a Resnet based NN for classifying anything.

The homework for this lesson is to apply the same technique on any image classification problem. I myself applied this same notebook to classify [Flowers](https://github.com/dzlab/deepprojects/blob/master/classification/102_Category_Flower_Dataset.ipynb), [Birds](https://github.com/dzlab/deepprojects/blob/master/classification/Caltech_UCSD_Birds_200_2011.ipynb) and even [Sounds](https://dzlab.github.io/jekyll/update/2018/11/13/audio-classification/).

#### Lesson 2
In this lesson Jemerey takes us deeper into Computer Vision through a teddy bear classification example, walk us through a detailled explication of the solution. Then explains interactively using a notebook what is the algorith [Stochastic gradient descent ](https://en.wikipedia.org/wiki/Stochastic_gradient_descent), and how it's updates the NN weights and get better and better at classifying images. The lessong ends with the introduction of some technical vocabulary:
- **Learning rate**: a critical number used to by gradient to control the amount to update the weights.
- **Epoch**: the number of iterations in the trainning phases. In every run, the trainng goes over all the data points (i.e. every image in the dataset). The number of epochs should not be too high, otherwise the training will see the same images many times and may overfitt and not generalize well.
- **Mini-batch**: A random set of data points that the training algorithm uses to update weights.
- **SGD**: Gradient descent using mini-batches.
- **Model** / **Architecture**: like ResNet34, generally speaking it can be seen as the mathematical function $$\vec{y} = X\vec{a}$$ we are trying to find the parameters to solve.
- **Parameters** / **Coefficients** / **Weights**: Numbers updating after every mini-batch.
- **Loss function**: a function used to assess how well the predictions $$\hat{y}$$ are compared to the real $$y$$. In classification problems, we usually uses cross entropy loss, also known as negative log likelihood loss. This penalizes incorrect confident predictions, and correct unconfident predictions.
- **Underfitting** and **Overfitting**: underfitting is when the model fails miseralby to predict the outputs in the training set (i.e. was not able to learn well from the data). On the other hand, the model is overfitting when it learns very well to predict the outputs on the training set but fails to generalize on unseen data points (i.e. the loss is very low on training set, but very hign on test dataset).
- **Regularization**: Regularization techniques help us make sure when we train our model that it's going to work not only well on the data it's seen but on the data it hasn't seen yet.
- **Validation Set**: at the end of a mini-batch SGD training loop, data from the validation set (i.e. samples not seen during training) are used in the calculation of the loss function and the accuracy to see how good the model is able to generalize.

The homework for this lesson is to build an image classification model and deploy it on a web app.

#### Lesson 3
The lesson takes time explaining the fancy learning rate plot and how you can interpret it.
It also presents a couple of jupyter notebooks for a variety of Deep Learning problems along with the trick that can be used to get good results:
- Multilabel dataset (each image has multiple labels).
- CamVid dataset (segmentation): the difference is in the use of U-Net with ResNet architecture. 
- BIWI dataset (regression, i.e. predict a contiguous number): the difference is in the loss function, in classifiation we tend to use cross entropy, for regression use mean square error.
- IMDB dataset: sentiment classification

#### Lesson 4

#### Lesson 5

#### Lesson 6

#### Lesson 7


![transfert_training]({{ "/assets/20181220-transfer-learning.jpg" | absolute_url }}){: .center-image }

By the end of the course, you will understand the fundamental ideas Jeremy cares a lot about, like:
- [Transfert learning](https://en.wikipedia.org/wiki/Transfer_learning), the reuse of pre-trained neural networks.
- Speeding up NN learning with [One fit cycle](https://sgugger.github.io/the-1cycle-policy.html), Descrimitive Learning, Momentum.
- Fine tunning a NN by deleting Layer (usually head) and replace it with ones useful for your problem.
- Random initialization of weights
- Gradullay Freezing & unfreezing layers of the architecture.
- To not be afraid of using big NN and addressing over-fitting with regularization techniques such [Weight Decay](http://www.faqs.org/faqs/ai-faq/neural-nets/part3/section-6.html), [Dropout](https://en.wikipedia.org/wiki/Dropout_(neural_networks)), [Batch Normalization](https://en.wikipedia.org/wiki/Batch_normalization).