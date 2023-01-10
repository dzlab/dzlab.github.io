---
layout: post
comments: true
title: Prompt engineering for question answering with LangChain
excerpt: Learn how to use LangChain for language models prompt engineering specifically for a question answering application
tags: [nlp,langchain]
toc: true
img_excerpt:
---

Large language models (LLMs) like GPT-3 can produce human-like text given an initial text as prompt. They can also be [customised](https://openai.com/blog/customized-gpt-3/) to perform a wide variety of natural language tasks such as: translation, summarization, question-answering, etc.

This customization steps requires tweaking the prompts given to the language model to maximize its effectiveness. This tweaking process requires many attempts/modification to the prompt and hence is also known as [Prompt engineering](https://docs.cohere.ai/docs/prompt-engineering).
In the rest of this article we will explore how to use [LangChain](https://github.com/hwchase17/langchain) for a question-anwsering application on custom corpus. LangChain is a python library that makes the customization of models like GPT-3 more approchable by creating an API around the Prompt engineering needed for a specific task.

## Enter LangChain

### Introduction
LangChain provides prompt templates for per task (e.g. question answering) and Data Augmented Generation to augment the knowledge of the LLM by providing more contextual data. For instance, for question answering the templace can be found [here](https://github.com/hwchase17/langchain/blob/master/langchain/chains/qa_with_sources/stuff_prompt.py) and looks like this:

```
Given the following extracted parts of a long document and a question, create a final answer with references ("SOURCES").
If you don't know the answer, just say that you don't know. Don't try to make up an answer.
ALWAYS return a "SOURCES" part in your answer.

QUESTION: {question}
=========
Content: ...
Source: ...
...
=========
FINAL ANSWER:
SOURCES:
```

You can see that the templace:
1. starts with a general prompt `Given the following extracted parts ..` then
1. highlights the question with `QUESTION` then
1. enumerates a squence of `Content` and `Source` clauses, and finally
1. highlighs the right answer with `FINAL ANSWER` and `SOURCES`

This is a concrente example of how the earlier prompt template looks like in practice
```
QUESTION: Which state/country's law governs the interpretation of the contract?
=========
Content: This Agreement is governed by English law and the parties submit to the exclusive jurisdiction of the English courts in relation to any dispute (contractual or non-contractual) concerning this Agreement save that either party may apply to any court for an injunction or other relief to protect its Intellectual Property Rights.
Source: 28-pl

Content: No Waiver. Failure or delay in exercising any right or remedy under this Agreement shall not constitute a waiver of such (or any other) right or remedy.\n\n11.7 Severability. The invalidity, illegality or unenforceability of any term (or part of a term) of this Agreement shall not affect the continuation in force of the remainder of the term (if any) and this Agreement.\n\n11.8 No Agency. Except as expressly stated otherwise, nothing in this Agreement shall create an agency, partnership or joint venture of any kind between the parties.\n\n11.9 No Third-Party Beneficiaries.
Source: 30-pl

Content: (b) if Google believes, in good faith, that the Distributor has violated or caused Google to violate any Anti-Bribery Laws (as defined in Clause 8.5) or that such a violation is reasonably likely to occur,
Source: 4-pl
=========
FINAL ANSWER: This Agreement is governed by English law.
SOURCES: 28-pl
```

### Usage
Using LangChain is straightforward. First, we would need to install the dependencies

```shell
$ pip install langchain requests transformers faiss-cpu
```

Next, import LangChain modules. Specifically a QA chain and a language model (e.g. OpenAI GPT-3).

> Note: LangChain support other language models (e.g. `HuggingFacePipeline` or [Cohere](https://cohere.ai/)) but support for the question answering task may not be available as of now.

```python
from langchain.llms import OpenAI
from langchain.chains.qa_with_sources import load_qa_with_sources_chain
from langchain.docstore.document import Document
import requests
```

Now, we instantiate an OpenAI client to use as our language models
```python
llm = OpenAI(temperature=0)
```

> Note: we need to set the `OPENAI_API_KEY` environment variable to be able to use OpenAI client, you can get a key at https://beta.openai.com/account/api-keys

Then wrap the language model in a Question-Answering [chain](https://langchain.readthedocs.io/en/latest/modules/chains.html) as follows:
```pyhon
chain = load_qa_with_sources_chain(llm)
```

For the question answering example we will use data from Wikipedia to build a toy corpus. The following helper function fetches articles from Wikipedia and creates LangChain `Document`s.

```python
def query_wikipedia(title, first_paragraph_only=True):
  base_url = "https://en.wikipedia.org"
  url = f"{base_url}/w/api.php?format=json&action=query&prop=extracts&explaintext=1&titles={title}"
  if first_paragraph_only:
    url += "&exintro=1"
  data = requests.get(url).json()
  return Document(
    metadata={"source": f"{base_url}/wiki/{title}"},
    page_content=list(data["query"]["pages"].values())[0]["extract"],
  )
```

Now we can download some articles
```python
sources = [
  query_wikipedia("Michelangelo"),
  query_wikipedia("Claude_Monet"),
  query_wikipedia("Alexandre_Dumas"),
  query_wikipedia("Victor_Hugo"),
]
```

Finally we put everything together in the following helper function that will return the language model answers given document sources and a question:
```python
def qa(chain, question):
  inputs = {"input_documents": sources, "question": question}
  outputs = chain(inputs, return_only_outputs=True)["output_text"]
  return outputs
```

Now we can test using a simple question
```python
qa(chain, "Who wrote Les Misérables?")
```
or a more complicated question like this
```python
qa(chain, "What are the main differences between Victor Hugo and Alexandre Dumas writing styles?")
```

## Handling large corpus
The previous simple chain would work for small corpus or small documents, but will not work for larger sets. For instance, OpenAI implements a size limit on the prompt which means we cannot sends requests with large text body.

LangChain provides couple workarounds for those limitations. Let's examine them in the following subsections.

### Using a map-reduce chain
When creating a chain we can pass a `chain_type` argument that takes one of the following values (see [documentation](https://langchain.readthedocs.io/en/latest/examples/data_augmented_generation/qa_with_sources.html)):

- `stuff` used as the default value, it simply indicates that the chain will combine all of the input sources into the prompt
- `map_reduce`: maps over the input sources and summarizes them. Then use the summaries when building the prompt.
- `refine`: iterates over the input sources and query the language model for answers.

We can test one of those chain types as follows
```python
mapred_chain = load_qa_with_sources_chain(llm, chain_type="map_reduce")
qa(mapred_chain, "your question here")
```

### Using a vector store
You may notice that using anything than the `stuff` type will result in more queries to the underlying language model. This may lead to longer response times when using long ducuments or large corpus.
To speed up search, LangChain allow us to combine language models with search engines (e.g. [FAISS](https://engineering.fb.com/2017/03/29/data-infrastructure/faiss-a-library-for-efficient-similarity-search/)) as follows
- Ahead of time, index all sources using a traditional search engine
- At query time, use the question to query the search index and select top _k_ (e.g. 2) results.
- The selected documents are used as sources for a chain of type `stuff`.

We can build a search index with FAISS as follows
```python
from langchain.embeddings.openai import OpenAIEmbeddings
from langchain.vectorstores.faiss import FAISS

vector_store = FAISS.from_documents(sources, OpenAIEmbeddings())
```

> Note: we are using OpenAI API to create embeddings for each document.

Finally, we can use the search index to lookup for answers as follows

```python
def qa_vector_store(chain, question):
  inputs = {
    "input_documents": vector_store.similarity_search(question, k=4),
    "question": question
    }
  response = chain(inputs, return_only_outputs=True)
  outputs = response["output_text"]
  return outputs
```

Now, we can test everything with questions
```python
qa_vector_store(chain, "your question here")
```


### Using text splitter
Very large documents may still pose problems, for this we can use a text splitter to chunk them into multiple smaller documents. LangChain provides a [text_splitter](https://langchain.readthedocs.io/en/latest/reference/modules/text_splitter.html) to do this, and we can leverage it to chunk our wikipedia documents as follows:

```python
from langchain.text_splitter import CharacterTextSplitter

def chunk(sources):
  splitter = CharacterTextSplitter(separator=" ", chunk_size=1024, chunk_overlap=0)
  chunks = []
  for src in sources:
    for chunk in splitter.split_text(src.page_content):
      document = Document(page_content=chunk, metadata=src.metadata)
      chunks.append(document)
  return chunks
```

In the previous function, `CharacterTextSplitter` is configured to split documents on whitespaces and create chunks of maximum size of 1024 characters. LangChain supports other types of splitters that may work better, check the [documentation](https://langchain.readthedocs.io/en/latest/reference/modules/text_splitter.html)


We can also fill the FAISS vector store with chunks instead of the full documents as follows 
```python
vector_store = FAISS.from_documents(chunks, OpenAIEmbeddings())
```

## That's all folks
I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
