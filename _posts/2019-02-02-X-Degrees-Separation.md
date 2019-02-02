---
layout: post
comments: true
title: X Degrees of Separation with PyTorch
categories: dl
tags: [dl, cnn, similarity]
toc: true
#img_excerpt: assets/*.jpg
---


Google X Degrees of Separation ([link](https://artsexperiments.withgoogle.com/xdegrees/
)) is an Artistic experiment made in collaboration by Google and artist [Mario Klingemann](https://twitter.com/quasimondo). This online tool uses AI to build a path between two images so that the in between images constitue and natural jump from one image to the other until the final image.

<div align="center">
<iframe width="560" height="315" src="https://www.youtube.com/embed/xgnxnmqnR7Y" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

The basic idea behind this tool, is to extract images features from the dataset and use these features to calculate the how close are each pair of images in the dataset (a.k.a [Similarity](https://en.wikipedia.org/wiki/Similarity_learning)). These distances are later used to build a graph with images as nodes connected with a weithed edge based on the distance between the two nodes. As a result, finding the shortest path between two images become a [classic graph problem](https://en.wikipedia.org/wiki/Shortest_path_problem).


![WikiArt_Sample]({{ "/assets/20190202-wikiart_sample.png" | absolute_url }}){: .center-image }


Full notebook can be found here - [link](https://github.com/dzlab/deepprojects/blob/master/artistic/X_degrees_of_separation_pytorch.ipynb)
