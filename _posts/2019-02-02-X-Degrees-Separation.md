---
layout: post
comments: true
title: X Degrees of Separation with PyTorch
categories: dl
tags: [dl, cnn, pca, tsne]
toc: true
img_excerpt: assets/20190202-wikiart_shortest_path.png
---

> What is the connection between a 4000 year old clay figure and Van Gogh's Starry Night? How do you get from Bruegel's Tower of Babel to the street art of Rio de Janeiro? What links an African mask to a Japanese wood cut?

Google X Degrees of Separation ([link](https://artsexperiments.withgoogle.com/xdegrees/
)) is an Artistic experiment made in collaboration by Google and artist [Mario Klingemann](https://twitter.com/quasimondo). This online tool uses AI to build a path between two images so that the in between images constitue and natural jump from one image to the other until the final image.

<div align="center">
<iframe width="560" height="315" src="https://www.youtube.com/embed/xgnxnmqnR7Y" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

The basic idea behind this tool, is to extract images features from the dataset and use these features to calculate the how close are each pair of images in the dataset (a.k.a [Similarity](https://en.wikipedia.org/wiki/Similarity_learning)). These distances are later used to build a graph with images as nodes connected with a weithed edge based on the distance between the two nodes. As a result, finding the shortest path between two images become a [classic graph problem](https://en.wikipedia.org/wiki/Shortest_path_problem).


The following article describes a simple approach to implement X Degrees of Separation with PyTorch.

## Data
The data used is a subset from [WikiArt Emotions](http://saifmohammad.com/WebPages/wikiartemotions.html) dataset which is a subset of about 4000 visual arts from the [WikiArt](https://www.wikiart.org/) encyclopedia. The following is a sample from this dataset.
![WikiArt_Sample]({{ "/assets/20190202-wikiart_sample.png" | absolute_url }}){: .center-image }

## Strategy
The approach to the replicate the X Degrees of Separation tool is as follows:

### 1) Feature extraction:
Extract classification features from each image in the dataset by using an pre-trained model (on imagenet for instance) as follows:
{% highlight python %}
# base model: imagenet classifier
model = models.resnet18(pretrained=True)
# feature extractor from the base model, up to the layer before average pooling
feature_modules = list(model.children())[:-2]
feature_extractor = nn.Sequential(*feature_modules)
# for every batch in the DataLoader
for batch in dataloader:
    # get the input (we don't need the labels)
    X, y = batch
    # run the model to get the image features
    preds = feature_extractor(X)
    # preds shape is: batch_size, 512, 4, 4 (i.e. output of the last BatchNorm layer)
    # avergare over the the last two dimensions
    features_batch = preds.mean(-1).mean(-1)
{% endhighlight %}
Then to speed up the calculation of distance between each image, apply a [PCA](https://en.wikipedia.org/wiki/Principal_component_analysis) to compress those features into orthogonal feautre vectors. This is done simply as follows:
{% highlight python %}
import fbpca
(U, s, Va) = fbpca.pca(features, k=10, raw=True, n_iter=10)
features_pca = U
{% endhighlight %}



Full notebook can be found here - [link](https://github.com/dzlab/deepprojects/blob/master/artistic/X_degrees_of_separation_pytorch.ipynb)
