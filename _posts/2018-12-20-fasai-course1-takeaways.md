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

> Here is [lecture notes](https://github.com/hiromis/notes), kindly shared by [Hiromi Suenaga](https://twitter.com/hiromi_suenaga) one of the course students.

#### Lesson 1

#### Lesson 2

#### Lesson 3
How to read learning rate plot at 1:30:25

What trick for what problem:

Multilabel dataset (each image has multiple labels): 
CamVid dataset (segmentation): the difference is in the use of U-Net with ResNet architecture. 
BIWI dataset (regression, i.e. predict a contiguous number): the difference is in the loss function, in classifiation we tend to use cross entropy, for regression use mean square error.
IMDB dataset: 

#### Lesson 4

#### Lesson 5

#### Lesson 6

#### Lesson 7


![transfert_training]({{ "/assets/20181220-transfer-learning.jpg" | absolute_url }}){: .center-image }

By the end of the course, you will understand the fundamental ideas Jeremy cares a lot about, like:
- [Transfert learning](https://en.wikipedia.org/wiki/Transfer_learning), the reuse of pre-trained neural networks.
- Speeding up NN learning with [One fit cycle](https://sgugger.github.io/the-1cycle-policy.html), Descrimitive Learning, Momentum.
- Fine tunning a NN by deleting Layer (usually head) and replace it with ones useful for your problem. - Random initialization of weights
- Gradullay Freezing & unfreezing layers of the architecture.
- To not be afraid of using big NN and addressing over-fitting with regularization techniques such [Weight Decay](http://www.faqs.org/faqs/ai-faq/neural-nets/part3/section-6.html), [Dropout](https://en.wikipedia.org/wiki/Dropout_(neural_networks)), [Batch Normalization](https://en.wikipedia.org/wiki/Batch_normalization).