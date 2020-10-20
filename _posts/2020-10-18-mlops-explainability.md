---
layout: post
comments: true
title: Explainable and Trustworthy AI in production
categories: ml
tags: [mlops, monitoring]
toc: true
#img_excerpt: assets/2020/10/20201013-.svg
---

Machine learning systems are getting more complex over time, for instance [GPT-3]({{ "ml/2020/07/25/gpt3-overview/" | absolute_url }}) is a model with hundreds of billions of parameters that requires a cluster of machines to run. And many of them are often “black boxes” for regular users and their internal functioning is only understood by experienced data scientists.

A machine learning system that is deployed to production and whoose prediction may affect a person's life have to be trustworthy and make its decision process transparent to users. Trustworthiness in machine learning entails a lot of aspects: privacy, safety, robustness, fairness, explainability, transparency, value alignment, and social good.

This article focus on deploying Explainability for machine learning systems in production.


## The need for Explainabile AI
Defined simply, Explainability is the extent to which the internal mechanics of an ML system can be explained in human terms. It is literally about explaining what is happening in side a model. Explainability is desirable for multiple reasons. In fact, by allowing users to verify the factors contributing to certain predictions, Explainability
* Builds trust in the predictions made by the system and improve transparency.
* Introduces a layer of accountability.

Furthermore, the wide spread usage of pre-trained models (especially in Computer Vision and lately in Natural Language Processing) can introduce harmful model bias during fine-tuning for a specific downstream task (e.g. image or text classification). This is because the data that the original model was pre-trained on is not controlled/curated by the downstream user. For example Word2Vec a popular pre-trained word embeddings is known to have serious gender bias and if used improperly can lead to serious discrimination.


Explainaility goes hand in hand with other ML monitoring techniques like anomaly or drift detection (learn more about [model monitoring]({{ "ml/2020/09/30/mlops-monitoring/" | absolute_url }})). In fact, they complement each other, for example, in case the model input is flagged as an outlier, explanability techniques can be used to assess the trustworthiness of the model predection on this input.

## Explainabilily techniques
The field of explainable AI is rich with different approaches and techniques, not all of them were created equal. Some are suitable for specific kind of models others are generally applicable to any model (from neural net to tree-based models). The data modality also impact the choice of the Explainabilily technique, in addition to the prediction task (e.g. regresssion vs classification).

To choose the right technique, it is also important to know the heuristic nature and the assumptions (e.g. background values) it makes during the process of explanation. Plus these techniques have different output and functioning (some requires heavier computation that others).


Each of the available techniques has its own strenght and pitfalls, but one can combine multiple approaches to provide a holostic explanation that sheds light on the impact of the training data (e.g. size or class unbalance) and relative feature importance. The latter, attempt to discover the key features to maintain the original prediction and by how much they can be distrubted so the model change its prediction.


### Impact of the training data
Explanation techniques based on [influence functions](https://christophm.github.io/interpretable-ml-book/influential.html) highlight which instances form the training set had the most impact on a specific prediction at inference time. An example of an influencial instance is an outlier (see following diagram).

Such techniques allow the user to check whether the most impactful training data
contain relevant features compared to the instance we are trying to explaine in production.


|![influential-point](https://christophm.github.io/interpretable-ml-book/images/influential-point-1.png){: .center-image }|
|A linear model with one feature. Trained once on the full data and once without the influential instance. Removing the influential instance changes the fitted slope (weight/coefficient) drastically - [source](https://christophm.github.io/interpretable-ml-book/influential.html).|

### Feature importance
One way to check for Feature importance is by trying to find which features are key in the final model prediction for a given instance regardless of the values of the other features using [Anchor explanations](https://christophm.github.io/interpretable-ml-book/anchors.html).

Another way, Feature attribution techniques evaluate the relative feature importances with respect to a model prediction. For example by trying to perturb the original instance to find the minimal change which will change the model prediction while still respecting the
class-conditional data distribution.

Such techniques include:

* [SHAP](https://github.com/slundberg/shap) (SHapley Additive exPlanation) which leverages the idea of [Shapley values](https://christophm.github.io/interpretable-ml-book/shapley.html) for scoring the influence of a model features. This is an exhaustive approach that considers all possible predictions for an instance using all inputs combinations. This makes SHAP explanation consistent but very slow to generate.
* [LIME](https://github.com/marcotcr/lime) (Local Interpretable Model-agnostic Explanations) builds sparse linear models around each prediction to explain how the underlying model works. LIME is less accurate but much faster to run than SHAP.
* [Integrated Gradients](https://github.com/hiranumn/IntegratedGradients) tries to approximate the Shapley values for the input features. These values allocate the difference between the model prediction for the background vs the prediction for the current instance.

## Explainabilily in Production
As described earlier, not all Explainabilily techniques were created equals. Some requires access to the model internals (e.g. Integrated Gradients requires access to the model gradients for a given input) thus the name **white-box** approaches. Others, requires nothing more then access to a prediction API thus the name **black-box** approaches.

The latter techniques are more convinient to a production deployement as the model to explain is usually deployed in isolation as a service with a well defined API (e.g. URL, request/reponse bodies).

The way one would use a **Black-box** to explain a model deployed in production is by repeatedly querying the model with a slighlty perturbated version of the original input instance so that it creates an approximation of model inference behavior. The way the queries are constructed depends on the input instances and their perturbated versions, as well as the explanation output of the **Black-box** explainer.

In a production environemnt, such setup can be deployed by having two different endpoints:
* `/prediction` endpoint which receives data requests to generate a prediction responses.
* `/explaination` endpoint which receives data requests but instead of generating predictions, it will implement the explanation algorithm and forward requests with multiple modified versions of the original input to the `/prediction` endpoint and then approximate an explanation response.

For scale reasons, it is advisable that:
* The `/prediction` endpoint should be duplicated so that actual prediction requests are forwarded to a separate instance than explanation requests (which have a lower priority).
* Also, due to the nature of prediction requests which usually requires low latency and have to be handled in real time vs the explanation requests which can have higher latency, the latter can be served asynchronously.

The following sequence diagram illustrates such deployment and interactions between the endpoints.


![explainability-seqdiagram]({{ "assets/2020/10/20201018-explainability-seqdiagram.svg" | absolute_url }}){: .center-image }

Notice in the explanation loop, how the explainer tried to perturb the original input data **xyz** that using the **?** charachter (e.g. modified version **x?z**) until the model predict a different label **def** than the original one **abc**.


## References
* Interpretable Machine Learning by Christoph Molnar - [link](https://christophm.github.io/interpretable-ml-book/).
* Explainability in Neural Networks by Prasad Chalasani - [link](https://deep.ghost.io/simple-feature-attribution/)