---
layout: post
comments: true
title: Train ULMFiT Language Model with Wikipedia
categories: nlp
---

Language Modeling (LM) is one of the mean tasks in natural language processing (NLP). Put simply, it aims to predict the next word based on a sequence. For example, given the sentence "I am writing a ...", the word coming next can be "email", or "blog post". Put formally, given a sequence of words x(1), x(2), ..., x(t), language models compute the probability distribution of the next word x(t+1). This probblem can be solved by many different algorithms.

Before anything, first thing to do in any Machine Learning task is gathering the right Data and cleaning it. In the case of NLP tasks, the data is a collection of texts (also called **corpus**) that can be of the same language (e.g. for building a language model), or spanning over multiple languages.
The Internet is filled of text data, for instance Wikipedia is a great text source and freely available.

In the following, we will first build an Arabic corpus from Wikipedia articles, then train a Language Model on it, to finally predict sentences starting with some initial words.

## Data
Starting from a raw Wikipedia dump file costruct a corpus for training a Language Model.

### Download the Wikipedia Dump File
A Wikipedia database dump file is quite large (e.g. English [dumps](https://dumps.wikimedia.org/enwiki/latest/) are more than 10GB), so downloading, storing, and processing such file can be tricky.

In the following, the Arabic language dump for 2018-11-01 is used (around 800MB). More dumps for Arabic can be found in on Wikipedia dumps - [link](https://dumps.wikimedia.org/arwiki/). First download the data, (no need to un-compress it) and have a look to the different files

{% highlight bash %}
$ curl -O https://dumps.wikimedia.org/arwiki/20181101/arwiki-20181101-pages-articles-multistream.xml.bz2
$ ls -alt
-rw-rw-r--.  1 dzlab dzlab 742398542 Nov 21 18:11 arwiki-20181101-pages-articles-multistream.xml.bz2
{% endhighlight %}

### Create a Corpus
The `arwiki-20181101-pages-articles-multistream.xml.bz2` file is writting in Wikipedia markup language, it contains a mix of page contents, links to other pages or translated versions, images, etc. It needs to be cleaned which can be done using a topic modeling library like [gensim](https://radimrehurek.com/gensim/). The following Python scripts uses gensim's [WikiCorpus class](https://radimrehurek.com/gensim/corpora/wikicorpus.html) to construct a corpus from a Wikipedia (or other MediaWiki-based) database dump and store it into multiple text files, each one with same number of articles.

{% highlight python %}
#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
from gensim.corpora import WikiCorpus

def next_fname(output_dir, num=0):
    """Get the next filename to use for writing new articles."""
    count = 0
    fname = output_dir + '/' + '{:>07d}'.format(num) + '.txt'
    return count, (num+1), fname

def make_corpus(input_file, output_dir, size=10000):
    """Convert Wikipedia xml dump file to text corpus"""

    wiki = WikiCorpus(input_file)
    count, num, fname = next_fname(output_dir)
    output = open(fname, 'w')

    # iterate over texts and store them
    for text in wiki.get_texts():
        output.write(bytes(' '.join(text), 'utf-8').decode('utf-8') + '\n')
        count += 1
        if (count == size):
            print('%s Done.' % fname)
            output.close()
            count, num, fname = next_fname(output_dir, num)
            output = open(fname, 'w')

    # clean up resources
    output.close()
    print('Completed.')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('Usage: python wikicorpus.py <wikipedia_dump_file> <destination_directory> <file_size>')
        sys.exit(1)
    input      = sys.argv[1]
    outupt_dir = sys.argv[2]
    file_size  = sys.argv[3] if len(sys.argv) else None
    make_corpus(input, outupt_dir)
{% endhighlight %}

Make sure the gensim library is installed
{% highlight bash %}
$ pip install gensim
{% endhighlight %}

Turn the above script into an executable and run it against `arwiki-20181101-pages-articles-multistream.xml.bz2`:
{% highlight bash %}
$ chmod +x wikicorpus.py
$ ./wikicorpus.py arwiki-20181101-pages-articles-multistream.xml.bz2 /path/to/destination
{% endhighlight %}
**Note** the extraction of the texts from the `.bz2` file is a very slow operation.

## Model

### PreProcessing
First thing, load the raw text files and tokenize them using the appropriate Tokenizer.
{% highlight python %}
arbic = Tokenizer(lang='ar')
data_lm = TextLMDataBunch.from_csv(PATH, '0000000.txt', tokenizer=arbic, bs=48, header=None, text_cols=0, label_cols=None)
{% endhighlight %}

### Training
Once the data is in the right shape, instantiate a learn, find a suitable learning rate and train it for couple of epochs.
{% highlight python %}
learn = language_model_learner(data_lm, drop_mult=0.3)

learn.lr_find()
learn.recorder.plot(skip_end=12)

learn.fit_one_cycle(1, 5e-4, moms=(0.8, 0.7))

learn.fit_one_cycle(4, 2e-3, moms=(0.8, 0.7))

learn.lr_find()
learn.recorder.plot(0,30)

learn.fit_one_cycle(1, 1e-7, moms=(0.8, 0.7))
{% endhighlight %}

### Prediction
![LanguageModelArabicPredict]({{ "/assets/20181123-language_model_ar_predict.png" | absolute_url }})

The full jypiter notebook can be found here - [link](https://github.com/dzlab/deepprojects/blob/master/nlp/ULMFiT_Arabic_LM.ipynb).

Additional resources:
- Building Wikipedia text corpus - [link](https://www.kdnuggets.com/2017/11/building-wikipedia-text-corpus-nlp.html)
- Wikipedia monolingual corpora - [link](https://linguatools.org/tools/corpora/wikipedia-monolingual-corpora/)
- Wikipedia parallel titles - [link](https://github.com/clab/wikipedia-parallel-titles)