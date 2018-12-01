---
layout: post
comments: true
title: Sentiment Classification Task
categories: jekyll update
---
Next step in using Naive Bases Text Classifier https://people.csail.mit.edu/jrennie/papers/icml03-nb.pdf
Check from this https://medium.com/data-from-the-trenches/text-classification-the-first-step-toward-nlp-mastery-f5f95d525d73

http://nadbordrozd.github.io/blog/2016/05/20/text-classification-with-word2vec/
https://www.kaggle.com/reiinakano/basic-nlp-bag-of-words-tf-idf-word2vec-lstm


IMDB sentiment: positive/negative folder
term-document matrix:
- first create a vocaubarly, the list of all words that appeared (they will be the features),
- then turn each review into a vector of which words appear and how offten did they appear. This is resulting representation is called bag of word representation, it does not cotain the order of text, it is just a bag of the words (what words in it).

With this matrix we can do math, e.g. logistic regression. Before we will do something else called naive bayes.

Use sklearn CountVectorizer. Turn text into tokens, also called tokenization. Use a good tokenizer.
API:
 - `fit_transform()` to transoform the training text into term-document sparse matrix
 - `transform()` for the test/validation set to be transformed using the training vocabulary and order
 - `get_feature_names()` to get the list of vocabularies
 - `vocabulary\_[word]` to get the index of a word, kind reverse dictionnary

This representation was used for a long time and it worked pretty well, nowadays RNN are mostly used.
Naive Bayes:
log-count ratio r for each word f.
The trick is to add one row with all ones in order for the probability so that nothing ever become unfinitely unlikely. 

First calculate the probability for every word, then then calculate the probability, positive is 1 
$$ p( class = positive / document) =  \frac{p( d / c=1) * p(c=1)}{p(d)} $$ that's bayes rule
to simplify we divide everything by the case where class is negative.

$$ \frac{p(c=1/d)}{p(c=0/d)} = \frac{p( d / c=1) * p(c=1)}{p( d / c=0) * p(c=0)} $$

r = log( (ratio of feature f in positive documents / ratio of feature f in negative documents) )

$$p(c=1)$$ is the average of the labels, $$p(c=0) = 1 - p(c=1)$$
Naive approach is to consider the probabilities of the words of a document been independent (which is not true), so that we can multiply them together.

$$p(d)$$ i.e. probability of getting this movie review

Binarize Naive Bayes, as we don't care much if word 'absurd' appeared more than once use API sign() on document to turn positive number into 1 and negaive to 0


pre_preds = val_term_doc.sign() @ r.T + b
Instead of using those naive parameters (r, b) (theoritical models) why don't we learn them => LogisticRegression (Data driven model)
Use parameter dual=True for logistic regression.

Use regularization:
 - L1 (i.e. a $$\|w\|$$) tends to make things smaller separately
 - L2 (i.e. a $$w^2$$) tends to make everything smaller at the same time
 
 Try regularization and binary.
 
Trigrams are super helpful when dealing with order (e.g. not good) when using tokenizer. use max-feature parameter in the logistic regression to limit number of created features.


{% include disqus.html %}
