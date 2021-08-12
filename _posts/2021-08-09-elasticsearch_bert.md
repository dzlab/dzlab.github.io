---
layout: post
comments: true
title: Supercharging Elasticsearch with Transformers
excerpt: Learn how to combine Elasticsearch query DSL with Sentence Transformers to build semantic search.
categories: nlp
tags: [bert,elasticsearch,python]
toc: true
img_excerpt:
---

Elasticsearch query DSL provides the possibility to use custom logic for calculating the score for the returned documents using [script_score](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-script-score-query.html) query. In this article, we will leverage this functionality along with [Sentence Transformers](https://huggingface.co/sentence-transformers/bert-base-nli-mean-tokens#usage-sentence-transformers) to improve search result.

First, we load Sentence Transformers model and use it to calculate the embeddings of each document in the corpus. In this case, we are loading documents from a JSON file and processing each one individually:
```python
f = open('data.json',)
documents = json.load(f)
corpus = []
for doc in documents:
    text = doc['text']
    embeddings = model.encode(text)
    doc['embeddings'] = embeddings.tolist()
```
> Note: we covert the embeddings into list of double in order to serialize it later back to json and sending it as payload for Elasticsearch index API.

Second, we sotre the documents along with the calculating embeddings into the `test` index:
```python
from elasticsearch import Elasticsearch

es = Elasticsearch()

for idx, doc in enumerate(documents):
    res = es.index(index="test", id=idx+1, body=doc)
```

Now we are ready to call the search API. But first we need to calculate the embeddings for search query the same way we did for each indexed documents:
```python
query = "..."
query_vector = model.encode(text).tolist()
```

Finally, we use Cosine Similarity function to find among all documents which ones have an embeding vector the closest in distance to the embedding vector of the query:
```python
script_query = {
    "script_score": {
        "query": {"match_all": {}},
        "script": {
            "source": "cosineSimilarity(params.embeddings, doc['embeddings']) + 1.0",
            "params": {"embeddings": query_vector}
        }
    }
}
search_body = {
    "size": 10,
    "query": script_query,
    "_source": {"excludes": ['embeddings']}
}
result = es.search(index="myindex", body=search_body)
```
> Note how we pass the `query_vector` as a parameter in the API call, and we use `cosineSimilarity` function as the scorer method.