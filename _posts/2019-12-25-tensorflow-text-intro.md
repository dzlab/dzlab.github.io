---
layout: post
comments: true
title: Building models with tf.text
categories: nlp
tags: [tensorflow, prepreocessing]
toc: true
#img_excerpt: assets/2019/20191208-raggedtensor.png
---

The field NLP is going over a renaissance with spectacular advances in different tasks like search, Autocomplete, Translation, chatbots (see [The Economist interview with a bot](https://worldin.economist.com/article/17521/edition2020artificial-intelligence-predicts-future)). Those achivements were made possible thanks to SOTA models like Google's BERT and OpenAI's GPT-2 and particularly Transfer Learning capabilities of those models. And thanks to tools like Tensorflow and Tensorflow Hub, it is becoming easier to build models for your task from pre-trained ones and achieve SOTA results.


An important step in building a model is Text preprocessing which consist of:
* tokenization, i.e. extracting tokens from the original text
* numerization of those tokens, i.e. given a vocabulary of unique tokens attribute an integer to each one.

In a nutshell, basic preprocessing consists of:
```python
## Given an Input text
['Never tell me the odds!', "It's not my fault.", "It's a trap!"]

## Split sentence into tokens
[['Never', 'tell', 'me', 'the', 'odds!'], ["It's", 'not', 'my', 'fault.'], ["It's", 'a', 'trap!']]

## looked up in vocabulary for Token IDs
[[1, 3, 4, 10, 17], [16, 5, 7, 18], [16, 2, 11]]
```

This step is very imporant as it could influence dramatically the performance of the final model. It can be a tedious and error-prone step despite the availability of excellent tools like [Spacy](https://spacy.io/), [NLTK](https://www.nltk.org), [GenSim](https://radimrehurek.com/gensim/). In fact those same tools can lead to a Training / Serving Skew as the preprocessing will be performed **outside tensorflow graph**.

> Training / Serving Skew is usually caused during model serving, as a result of the preprocessing is performed in a different language/library which may causes issues.


[tf.text](https://www.tensorflow.org/tutorials/tensorflow_text/intro) aims to make text a first-class citizen in Tensorflow by providing built-in support for text in Tensorflow:
* In-graph text preprocessing for serving & training,
* Text and sequential (e.g. timeseries) model APIs
* RaggedTensors for better text representation

Thus no longer need for relying on the client for preprocessing during serving.

## Tokenizer API
Based on [RFC 98](https://github.com/tensorflow/community/blob/master/rfcs/20190430-tokenization-conventions.md), the Tokenization API introduced two main classes:
* **Tokenizer**: An abstract class with one method `tokenize` that takes strings or integer Tensor and outputs Tokens.
* **TokenizerWithOffsets**: An abstract class with one method `tokenize_with_offsets` that returns in addition to the tokens the offsets from where they start and end.

For instance, when using `WhitespaceTokenizer` (which implements both APIs)
```python
>>> (tokens, offset_starts, offset_limits) = tokenizer.tokenize_with_offsets(["I know you're out there.", "I can feel you now."])

(<tf.RaggedTensor [[b'I', b'know', b"you're", b'out', b'there.'], [b'I', b'can', b'feel', b'you', b'now.']]>,
 <tf.RaggedTensor [[0, 2, 7, 14, 18], [0, 2, 6, 11, 15]]>,
 <tf.RaggedTensor [[1, 6, 13, 17, 24], [1, 5, 10, 14, 19]]>)
```

Currently available tokenizers are:
* Whitespace: splits the sentence on whitespaces
* Unicode Script: splits on Unicode script boundaries (ICU), for english in addition to splitting on whitespaces it also splits on ponctuation.
* Wordpiece: popularized with BERT, split tokens further using a subword vocabulary. This greatly reduces the size of the vocabulary. There is a pipeline you can use to generate your own vocab use BERT vocabb.
* Sentencepiece: a popular tokenizer that splits bbased on model configuration (subword, word or character)
* BERT: does have all the preprocessing that matches BERT model

## RaggedTensors
RaggedTensors is a special Tensor that stores sequences (text or number) efficiently and does not require padding.

They can be created as follows:
```python
>>> tf.ragged.constant([['Everything', 'not', 'saved', 'will', 'be', 'lost.'], ["It's", 'a', 'trap!']])

<tf.RaggedTensor [[b'Everything', b'not', b'saved', b'will', b'be', b'lost.'], [b"It's", b'a', b'trap!']]>

>>> values = ['Everything', 'not', 'saved', 'will', 'be', 'lost.', "It's", 'a', 'trap!']
>>> row_splits = [0, 6, 9]
>>> tf.RaggedTensor.from_row_splits(values, row_splits)

<tf.RaggedTensor [[b'Everything', b'not', b'saved', b'will', b'be', b'lost.'], [b"It's", b'a', b'trap!']]>
```
Another example of creating RaggedTensors with Row lengths
```python
>>> tf.RaggedTensor.from_row_splits([3, 1, 4, 1, 5, 9, 2], [0, 4, 4, 6, 7])
>>> tf.RaggedTensor.from_value_rowids([3, 1, 4, 1, 5, 9, 2], [0, 0, 0, 0, 2, 2, 3])
>>> tf.RaggedTensor.from_row_lengths([3, 1, 4, 1, 5, 9, 2], [4, 0, 2, 1])
```
Ragged Tensors are regular tensors:
```python
x = tf.ragged.constant([['a', 'b', 'c'], ['d']])

tf.rank(x) # 2
x.shape # [2, None] where ? denote the ragged dimension which is not always at the end

tf.gather(x, [1, 0]) # [['d'], ['a', 'b', 'c']]
tf.gather_nd(x, [1, 2]) # d

y = tf.ragged.constant([['e'], ['f', 'g'])
tf.concat([x, y], axis=0) # [['a', 'b', 'c'], ['d'], ['e'], ['f', 'g']]
tf.concat([x, y], axis=1) # [['a', 'b', 'c', 'e'], ['d', 'f', 'g']]

cp = tf.strings.unicode_decode(x, 'UTF-8') # [[[97], [98], [99]], [[100]]]
tf.strings.unicode_encode(cp, 'UTF-8')

b = tf.ragged.constant([[True, False, True], [False, True]])
x = tf.ragged.constant([['A', 'B', 'C'], ['D', 'E']])
y = tf.ragged.constant([['a', 'b', 'c'], ['d', 'e']])
tf.where(, x, y) # [['A', 'b', 'C'], ['d', 'E']]
```

They can be creacted from other forms
```python
tf.RaggedTensor.from_tensor(x)
tf.RaggedTensor.from_sparse(x)
```
Also easily converted to other forms
```python
x.to_tensor()
x.to_sparse()
x.to_list()
```

Currently, RaggedTensors are compatible with a handful of Keras layers:
* Input
* Embedding
* Recurrent layers (SimpleRNN, GRU, LSTM, CuDNNGRU, CuDNNLSTM)
* Bidirectional
* TimeDistribbuted
* Lambda
* Global Pooling
* Merge
* tensorflow_text.ToDense

The `tensorflow_text.ToDense` layer can be used to convert a RaggedTensor into a regular Tensor in case your model has layers that does not support them. For instance:

```python 
model = tf.keras.Sequential([
  InputLayer(input_shape=(None,), dtype='int64', ragged=True),
  tensorflow_text.keras.layers.ToDense(pad_value=pad_val, mask=True),
  Lambda(lambda x:K.one_hot(K.cast(x,'int64'), vocab_size)),
  LSTM(lstm_output_1),
  Dense(vocab_size, activation='softmax')
])
model.compile(optimizer="adam", loss="sparse_categorical_crossentropy", metrics=["accuracy"])
```

## Tensorflow Text

tf.text can be install using pip as follows
```
pip install tensorflow_text
```
Then imported as follows
```python
import tensorflow as tf
import tensorflow_text as text
```

### Preprocessing
Using Tensorflow Text, a preprocessing function should look like this
```python
def basic_preprocess(text_input, labels):
  # Tokenize and encode the text
  tokenizer = text.WhitespaceTokenizer()
  rt = tokenizer.tokenize(text_input)

  # Lookup token strings in vocabulary
  features = tf.ragged.map_flat_values(table.lookup, rt)

  return features, labels
```
Create a dataset for training and pass each sample to the previous preprocessing function
```python
## Set up a data pipeline to preprocess the input
dataset = tf.data.Dataset.from_tensor_slices((text_input, labels))
dataset = dataset.map(basic_preprocess)

## Create a model to classify the sentence sentiment
model = keras.Sequential([.., keras.layers.LSTM(32), ...])
model.compile(...)

## Train the classifier on the input data
model.fit(dataset, epochs=30)
```

### Ngrams
Tensorflow Text provides an API to create Ngrams (i.e. a grouping of a fixed size over a series), which for instance can be used in a Character bigram model.

#### Group Reductions
Available group reductions (for different grouping ways): STRING_JOIN, SUM, MEAN

For instance, the MEAN reduction can be interesting for integer for instance if they represent temperature readings which a are gouped in 2 or 3 readings.

* STRING_JOIN bigram example

```python
t = tf.constant(["Fate, it seems, is not without a sense of irony."])
tokens = tokenizer.tokenize(t)
# [['Fate,', 'it', 'seems', 'is', 'not', 'without', 'a', 'sense', 'of', 'irony.']]

text.ngrams(tokens, width=2, reduction_type=text.Reduction.STRING_JOIN)
# [['Fate, it', 'it seems,', 'seems, is', 'is not', 'not without', 'without a', 'a sense', 'sense of', 'of irony.']]
```

* STRING_JOIN trigram example

```python
t = tf.constant(["It's a trap!"])
chars = tf.strings.unicode_split(t, 'UTF-8') # [['I', 't', "'", 's', ' ', 'a', ' ', 't', 'r', 'a', 'p', '!']]
text.ngrams(chars, width=3, reduction_type=text.Reduction.STRING_JOIN, string_separator='')
# [["It'", "t's", "'s ", 's a', ' a ', 'a t', ' tr', 'tra', 'rap', 'ap!']]
```

* Numeric (SUM, MEAN) bigram examples

```python
t = tf.constant([2, 4, 6, 8, 10])
text.ngrams(t, 2, reduction_type=text.Reduction.SUM)  # [6 10 14 18]
text.ngrams(t, 2, reduction_type=text.Reduction.MEAN) # [3 5 7 9]
```

#### Preprocessing with ngrams
The ngrams API can be used in a preprocessing function like this
```python
def preprocess(record):
  # ['Looks good.', 'Thanks!', 'Okay'] shape (3)
  # Convert characters into codepoints
  codepoints = tf.strings.unicode_decode(record['raw'], 'UTF-8')
  # [[76, 111, 111, 107, 115, 32, 103, 111, 111, 100, 46], [84, 104, 97, 110, 107, 115, 33], [79, 107, 97, 121]] shape(3, ?)
  codepoints = codepoints.merge_dims(outer_axis=-2, inner_axis=-1)

  # Generate bigrams
  bigrams = text.ngrams(codepoints, 2, reduction_type=text.Reduction.SUM)
  values = tf.cast(bigrams, dtype=tf.float32)
  labels = record.pop('attack')

  return values, labels
```
This preprocessing function can then be is used in a pipeline to generate training dataset for the model training
```python
# Set up a data pipeline to preprocess the input
dataset = tf.data.TFRecordDataset('.../*.tfrecord')
dataset = dataset.map(preprocess)

## Create a model to classify the sentence sentiment
model = keras.Sequential([..., keras.layers.LSTM(32), ...])
model.compile(...)

## Train the classifier on the input data
model.fit(dataset, epochs=30)
```

{% include disqus.html %}