---
layout: post
comments: true
title: Generating Synthetic Data for NLP tasks in Java with llm4j and PaLM
excerpt: How to Build a News article recommendation App in Java with llm4j, PaLM and Elasticsearch
tags: [genai,palm]
toc: true
img_excerpt:
---

![Synthetic data generation with PaLM]({{ "/assets/2023/09/20230922-palm-synthetic-data.svg" | absolute_url }})

Creating datasets for training Natural Language Processing (NLP) models is a complex and resource-intensive task. This is because the quality and diversification of the data have direct impact on the performance of the model. It gets even harder when bigger models as they will require a large amount of data for training.

One way to effectively manage the data collection at scale is to create a small (e.g. few hundrend examples) curated dataset of high-quality, then extend it using **Data Augmentation** techniques. An example of such techniques is to generate **Synthetic Data** to simulate cases or conditions not represented in the original dataset. Using Synthetic Data in this case is effective because it can be easily automated.

Large Language Models (LLMs) are often used to generate synthetic data. In the rest of this article, we will explore how to use Google PaLM with the [llm4j](https://github.com/llmjava/llm4j) library to generate a Wikipedia-based multi-question answering dataset that can be used to train an NLP model.

> Note: While using Synthetic Data offers several benefits, the quality and fidelity of the generated data should be carefully evaluated before use in real-world applications.


## Design Overview
The dataset will be formed using PaLM based on pages from Wikipedia. The task of the model is to generate multiple-choice questions from a chunk of text. The expected output is a well formatted multiple-choice question with options and a correct answer.

The above diagram illustrates the different steps for generating Synthetic data which we further explain here:
- Submit a search query on some subject, e.g. fruits.
- Select a page from Wikipedia that matches the query.
- Extract the text from the page and create small chunks
- Pass a prompt to the model with the needed instructions.
- Check if the model's output format is valid, then parse it.

The source code of this application can be found here - [palm-examples](https://github.com/llmjava/llm4j-examples/tree/main/palm-examples).

The rest of this article walks through the implementation in details. 

## Setup Google PaLM using llm4j
First we create a [LanguageModel](https://llmjava.github.io/llm4j/javadoc/org/llm4j/api/LanguageModel.html) object using the [LLM4J](https://llmjava.github.io/llm4j) library. We will use this object later for text generation and embedding using Google PaLM's API.

```java
Map<String, String> configMap = new HashMap<String, String>();
configMap.put("palm.apiKey", "${env:PALM_API_KEY}");
configMap.put("palm.modelId", "models/text-bison-001");
configMap.put("topK", "40");
configMap.put("topP", "0.95");
configMap.put("temperature", "0.7");
configMap.put("maxNewTokens", "1024");
configMap.put("maxOutputTokens", "1024");
configMap.put("candidateCount", "1");

Configuration config = new MapConfiguration(configMap);
LanguageModel palm = LLM4J.getLanguageModel(config, new PaLMLanguageModel.Builder());
```

> Note to connect to Google PaLM with LLM4J you need to set the environment variable `PALM_API_KEY` with the PaLM API Key that you can get from https://makersuite.google.com/app/apikey.


## Selecting with wikipedia4j


```java
Wikipedia wiki = new Wikipedia();
List<Document> results = wiki.search("apple");
String wikiText = results.get(0).getText();
List<Section> sections = WikipediaUtils.extractSections(wikiText);
```

Because we are limited in the number of tokens we can preset to PaLM for text generation, we need to split the wikipedia page into chunks.
```
= Header 1 =
Some text.

== Header 2 ==
More text.

=== Header 3.1 ===
Even more text.

=== Header 3.2 ===
Even more more text.

== Header 2 ==
More more text.
```

## Generating Questions and Answers with PaLM

Prompt template
```
You will be provided with TEXT from wikipedia. Output a list of multiple choice questions with 3 choices and answers from the TEXT.
You should tell me which one of your proposed options is right by assigning the corresponding option's key label in the 'answer' field.

The question, the answer and question answer options should be broad, challenging, long, detailed and based on the TEXT provided.

Only output the list of objects, with nothing else.

{delimiter}
TEXT: The ultraviolet catastrophe, also called the Rayleigh–Jeans catastrophe, was the prediction of late 19th century/early 20th century classical physics that an ideal black body at thermal equilibrium would emit an unbounded quantity of energy as wavelength decreased into the ultraviolet range.[1]: 6–7  The term "ultraviolet catastrophe" was first used in 1911 by Paul Ehrenfest,[2] but the concept originated with the 1900 statistical derivation of the Rayleigh–Jeans law. The "ultraviolet catastrophe" is the expression of the fact that the formula misbehaves at higher frequencies.
question: What is the 'ultraviolet catastrophe'?
option_1: It is a phenomenon that occurs only in multi-mode vibration.
option_2: It is the misbehavior of a formula for higher frequencies.
option_3: It is a flaw in classical physics that results in the misallocation of energy.
answer: option_2

{delimiter}
TEXT: {TEXT}
```
Which will generate an aswer that would look like this

```
question: What is the name of Odin's sword?
option_1: Gungnir
option_2: Tyrfing
option_3: Gram
answer: option_1
```

Or we can ask the LLM to generate a one line JSON object using the folloing prompt
```
You will be provided with TEXT from wikipedia. Output a list of multiple choice questions with 3 choices and answers from the TEXT. Format your output in a one line JSON object.
You should tell me which one of your proposed options is right by assigning the corresponding option's key label in the 'answer' field.

The question, the answer and question answer options should be broad, challenging, long, detailed and based on the TEXT provided.

Only output the list of objects, with nothing else.

{delimiter}
TEXT: The ultraviolet catastrophe, also called the Rayleigh–Jeans catastrophe, was the prediction of late 19th century/early 20th century classical physics that an ideal black body at thermal equilibrium would emit an unbounded quantity of energy as wavelength decreased into the ultraviolet range.[1]: 6–7  The term "ultraviolet catastrophe" was first used in 1911 by Paul Ehrenfest,[2] but the concept originated with the 1900 statistical derivation of the Rayleigh–Jeans law. The "ultraviolet catastrophe" is the expression of the fact that the formula misbehaves at higher frequencies.
{"question": "What is the 'ultraviolet catastrophe'?", "A": "It is a phenomenon that occurs only in multi-mode vibration.", "B": "It is the misbehavior of a formula for higher frequencies.", "C": "It is a flaw in classical physics that results in the misallocation of energy.", "answer": "B"}

{delimiter}
TEXT: {TEXT}
```

Which given [Ibn Battuta's wikipedia page](https://en.wikipedia.org/wiki/Ibn_Battuta) will generate
```
{"question": "Where did Ibn Battuta travel to after his visit to the Chagatai Khanate?", "A": "Bolghar", "B": "Constantinople", "C": "Afghanistan", "answer": "B"}
```


Example text input taken from wikipedia about the religious role of the apple fruit
```
Historicity, German Islamic studies scholar Ralph Elger views Battuta's travel account as an important literary work but doubts the historicity of much of its content, which he suspects to be a work of fiction compiled and inspired from other contemporary travel reports. Various other scholars have raised similar doubts.In 1987, Ross E. Dunn similarly expressed doubts that any evidence would be found to support the narrative of the Rihla, but in 2010, Tim Mackintosh-Smith completed a multi-volume field study in dozens of the locales mentioned in the Rihla, in which he reports on previously unknown manuscripts of Islamic law kept in the archives of Al-Azhar University in Cairo that were copied by Ibn Battuta in Damascus in 1326, corroborating the date in the Rihla of his sojourn in Syria.
```

PaLM 


```
{"question": "What is the stance on Ibn Battuta's Rihla?", "A": "It is a work of fiction compiled from other accounts.", "B": "It is a work of fiction but with some historical details.", "C": "It is a work of history with some fictional details.", "answer": "A"}
```




## That's all folks
LLMs have democratized the generation of synthetic data, which in turn has the potential to simplify and broaden a wide range of NLP tasks. However, synthetic data can become unfaithful in cases where the generative data distribution differs a lot from the distribution of real-world data.

In this article we saw how easy it is to interact with LLMs like PaLM in Java using the [LLM4J](https://llmjava.github.io/llm4j) library. Also how to programatically query articles from Wikipedia using [wikipedia4j](https://github.com/llmjava/wikipedia4j). And how to combine the capabilities of PaLM and Elasticsearch to build an embeddings-based article recommendation solution.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
