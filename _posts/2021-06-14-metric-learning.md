---
layout: post
comments: true
title: Metric Learning, What is Deep Metric Learning?
excerpt: Diving deep into metric based deep learning.
categories: dl
tags: [bert,elasticsearch,python]
toc: true
img_excerpt:
---

## Brief introduction (TL;DR)

Metric learning is simply to learn a metric function that quantifies the similarity between data well.

The metric function learned through metric learning is used in various fields such as clustering and few shot learning.

## Necessity of Metric Learning from the Few Shot Learning Perspective

![Face Verification](https://media.gettyimages.com/vectors/biometrics-of-a-woman-face-detection-recognition-and-identification-vector-id1131606997)


[Few shot learning](#glossary),
Among them, let's look at the necessity of Metric Learning through the example of Face Verification.

First, face verification is a task of determining whether a given pair of face images belongs to the same person.
It's easy if you think of FaceID when you unlock your smartphone.

### Why Verification is difficult

The above Verification task is essentially an Image Classification task in that it classifies whether two faces (registered face, face during authentication) are of the same class or not.

Also, in general, if a new user registers a new face, at most 10 or several face photos can be added to the data set.

Therefore, it is also a [Few shot learning](#glossary) task in that it uses only a few samples in a downstream task (new user classification).

There is a big problem here. Deep learning models have a high performance dependence on the amount of data. When training with a small amount of data, it is highly likely to lead to overfitting.

[Meta learning](#glossary) methodology can be applied to solve this fundamental problem of Few shot learning.
The metric learning we want to explore today can be used as one of these meta-learning approaches.

## Metrics:
In metric learning, metric is a non-negative function between two points $x$ and $y$ (let's say $d(x,y)$), and explains the so-called 'distance' concept between these two points.

Here are some properties that Metric must satisfy:

- *Non-negativity*

$d(x,y) \geqq 0$ and $d(x,y) = 0$, iff $x = y$

- *Triangular inequality*

$d(x,y) \leqq d(x,z) + d(z,y)$

- *Symmetry*

$d(x,y) = d(y,x)$

Let's look at some representative examples that satisfy the above conditions. (This part is not very closely related to the Deep Metric Learning we are going to look at, so you can skip it)

### Euclidean Metric
First, there is the Euclidean Metric that we are familiar with.

$$d({x}_1, {x}_2) = \sqrt{\sum_{i=1}^{d} ({x}_{1, i} - {x}_{2, i}) ^2}$$

However, Euclidean Metric is difficult to use in high-dimensional data due to several shortcomings ([Detailed explanation] (https://www.machinelearningplus.com/statistics/mahalanobis-distance/)). Simply put, Euclidean distances are isotropic (the same in all directions) without taking into account correlations between classes.

This allows us to use non-isotropic distances to capture interdimensional relationships.

### Mahalanobis Distance Metric

![Isotropic Euclidean distance V/S Non-isotropic Mahalanobis distance metric](https://miro.medium.com/max/1400/1*7CHW-oUiEkyk4_gHysXbvg.png)

The Mahalanobis Distance Metric is one such metric.

$$d(x_1,x_2) = \sqrt{((x_1-x_2)^TM(x_1,x_2))}$$

Here, $M$ is the inverse of the covariance matrix and acts as a weighted term for the square of the Euclidean Distance. The Mahalanobis distance equation can be viewed as an Euclidean Metric calculated after decorrelating the relationship between dimensions. ([Additional explanation](https://stats.stackexchange.com/questions/326508/intuitive-meaning-of-vector-multiplication-with-covariance-matrix))

In case $M$ is Identity Matrix, Mahalanobis Distance becomes equal to Euclidean Distance, and it can be seen that Euclidean Distance inherently assumes that the dimensions are essentially independent of each other.

### Limits of the predefined Distance Metric

Is it possible to classify by applying the above Euclidean Metric and Mahalanobis Distance Metric to the image pixel vector as it is?

In other words, if Euclidean Metric is used directly, is it the same face if the pixel mse is low and different faces if the pixel mse is large?

*Of course not.*

The distance metrics defined above are not suitable for our use because they do not consider data and tasks. (Even Mahalanobis Distance is just a linear transformation considering covariance.)

For this reason, it is metric learning to directly create a distance function suitable for data through machine learning, and deep metric learning is a case of using deep learning among machine learning.

## Metric Learning

Let's think about what basic machine learning does. Typically in machine learning, we give data and its labels, and devise a set of rules or complex functions that map that input to labels.

Similarly, the goal of metric learning is to learn a metric function from data.

To achieve this, we usually learn an embedding function $f$ that maps the original feature space to an embedding space that is easy to compute distances.

The metric function $d$ learned in this way is

$$d(x_1,x_2)=d_e(f(x_1),f(x_2))$$

am. Here, $d_p$ is the distance function between predefined embeddings such as euclidean distance and cosine similarity.

![image](https://img1.daumcdn.net/thumb/R1280x0/?scode=mtistory2&fname=https%3A%2F%2Fblog.kakaocdn.net%2Fdn%2Fdpuky0%2FbtqIjeVyxZo%2FSnmmbKkWybngk)

## Deep Metric Learning

Finally, we have arrived at this topic, Deep Metric Learning.

Above, you said that you want to learn the embedding function $f$ that maps the original feature space to the embedding space that is easy to calculate the distance.

When the distance function between embeddings is $d_e$, $x$ and $y$ are the input data, and $f$ is the embedding function, in the Classification task, we target and learn as follows.

- When $x$ and $y$ are of the same class, make $d_e(f(x), f(y))$ smaller
- If $x$ and $y$ are different classes, make $d_e(f(x), f(y))$ bigger

There are two ways to achieve this in Deep Metric Learning.

### Loss function design

The first is to use a loss function suitable for the above goal.

Among them, let's look at the representative Contrastive Loss and Triplete Loss.

#### Contrastive Loss

First, let's see what the Siamese Network is.

The Siamese Network is a symmetric neural network architecture composed of two identical sub-networks (shared parameters) (see figure below).

Siamese Network is mainly used together with Contrastive Loss to achieve the above goal. Looking at the formula of Contrastive Loss,

$$L(f(x), f(y), z) = z*d_e(f(x), f(y)) + (1-z)\text{max}(0, m-d_e(f (x), f(y)))$$

Here, $m$ is margin, and $z$ is ```int(class(x)==class(y))```.

![Siamese net](https://www.pyimagesearch.com/wp-content/uploads/2020/11/keras_siamese_networks_process.png)

Looking at the expression, if $x$ and $y$ are of the same class, $L(f(x), f(y), z) = d_e(f(x), f(y))$, so It is learned in the direction of narrowing the distance.

Conversely, if $x$ and $y$ are different classes, $L(f(x), f(y), z) = \text{max}(0, m-d_e(f(x), f(y) )))$, so it is learned in the direction of increasing the distance between different classes.

You may be wondering what m is, but when $x$ and $y$ are different classes, and the distance is already far enough ($d(f(x), f(y)) >= m$), the loss becomes 0. don't care any more.

This helps the model to learn by allowing it to focus more on the difficult parts.


#### Triplet Loss

The Triplet Network is also similar to the Siamese Network, but consists of three identical subnetworks instead of two.

It uses 3 inputs:

1. Anchor
2. Positive (Sample belonging to the same class as Anchor)
3. Negative (sample belonging to a different class than Anchor)

![Triplet loss](https://miro.medium.com/max/2800/1*MIPdyhJGx6uLiob9UI9S0w.png)

Looking at the expression,

$$L(f(a), f(p), f(n)) = \text{max}(0, d(f(a), f(p)) - d(f(a), f( n)) +m)$$

Here, $m$ is margin, and $a$, $p$, and $n$ are Anchor, Positive, and Negative, respectively.

If you look at $d(f(a), f(p)) - d(f(a), f(n)$, you can see that learning is conducted in the direction of narrowing the distance between the same class and increasing the distance between different classes.

Similar to Contrastive Loss above, $m$ is set. In triplet loss, if the distance difference between Positive Distance and Negative Distance is more than $m$, it is not reflected in the loss to help learning.

#### problem

Contrastive Loss and Triplet Loss have the advantage of being intuitive, but in order to learn effectively, they have the disadvantage of finding a good (ie, difficult) pair/triplet for learning through mining.

## Insight

So far, we have looked at the necessity of metric learning and the losses used in deep metric learning.

In Part 2, we will learn about Deep Metric Learning through classification model transformation.

## Glossary
Glossary of terms such as Meta learning, Transfer learning, Few shot learning, Finetuning, etc.
Let's check the definition of confusing kinds of learning

> Too many terms

When doing deep learning, you will come across terms such as meta learning, transfer learning, few shot learning, and finetuning.

Their correlation and hierarchy are often very confusing. I think it's because academia and industry use the term too recklessly.

This time, let's try to solve this confusion.



- **Meta Learning**: Learning to learn. That is, learning to learn problems that have not been encountered in the existing training time quickly/skillfully.
- **Transfer Learning** A technique for reusing a part of a model that has learned a specific task (upstream task) by transferring it to performing another task (downstream task).
- **Few shot Learning** It is a type of transfer learning that uses only a few samples of data in a downstream task.
- **One shot Learning** A type of transfer learning that uses only one piece of data in a downstream task.
- **Zero shot Learning** A type of transfer learning that is performed without using data from downstream tasks.
- **Finetuning** Retraining the existing model on new data at a low learning rate (whether or not to freeze depends on the situation)