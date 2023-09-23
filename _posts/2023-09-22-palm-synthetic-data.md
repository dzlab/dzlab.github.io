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

One way to effectively manage the data collection at scale is to create a small (e.g. few hundrend examples) curated dataset of high-quality, then extend it using **Data Augmentation** techniques. An example of such techniques is to generate **Synthetic Data** to simulate cases or conditions not represented in the original dataset. Using Synthetic Data in this case is effective because it can be easily automated with Large Language Models (LLMs).

In the rest of this article, we will explore how to use Google PaLM with the [llm4j](https://github.com/llmjava/llm4j) library to generate a Wikipedia-based multi-question answering dataset that can be used to train an NLP model.

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

## Querying Wikipedia
First, we query Wikipedia to get the text we will create questions from using the [wikipedia4j](https://github.com/llmjava/wikipedia4j) library as follows:

```java
Wikipedia wiki = new Wikipedia();
List<Document> results = wiki.search("apple");
String wikiText = results.get(0).getText();
```

The structure of the text in `wikiText` follows Wikipedia page syntax and will look like this:
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

In the above example, `= Header 1 =` is a top level header and `== Header 2 ==` is a second level header and so on. We can easily see a pattern for the headers of one or more equal signs, followed by any text, followed by the same number of equal signs.

We cannot pass such text as is to the LLM model because this particular structure can confuse it and also because the text can be very large. We need to do some pre-processing to clean up this text and extract the sections and their headers.

The following code snippet, uses a regular expression to match the headers, then it extracts the section text that follows a match.

```java
// Define a regex pattern to capture the text between the equal signs as a group
Pattern pattern = Pattern.compile("(=+)(.+?)\\1");

// Create a Matcher object that matches the pattern against the wikiText
Matcher matcher = pattern.matcher(wikiText);

// Initialize a variable to store the previous match end index
int prevEnd = 0;

Section previous = null;

// Loop through the matches and print the section level, title and text
while (matcher.find()) {
    // Get the number of equal signs in the match
    int level = matcher.group(1).length();

    // Get the text between the equal signs
    String title = matcher.group(2).trim();

    // Get the start and end indices of the match in the wikiText
    int start = matcher.start();
    int end = matcher.end();

    // Get the text between the previous match end and the current match start
    String text = wikiText.substring(prevEnd, start).trim();
    // Print the section level, title and text
    System.out.println(level + ". " + title + ": " + text);
    
    // Update the previous match end index
    prevEnd = end;
    previous = current;
}
```

> Note: Because we are limited in the number of tokens we can pass to PaLM for text generation, we need to further split the larger sections into smaller chunks, otherwise the model will return nothing.


## Google PaLM with llm4j
Next, we need to configure the access to Google PaLM for the [LLM4J](https://llmjava.github.io/llm4j) library. So, get a PaLM's API key from [Makersuite](https://makersuite.google.com/app/apikey) and then set the environment variable `PALM_API_KEY` with the value of the key.

Now, we can access PaLM for text generation in our Java application by creating a [LanguageModel](https://llmjava.github.io/llm4j/javadoc/org/llm4j/api/LanguageModel.html) instance as follows.

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

After creating an `LanguageModel` instance, we can simply ask to the generate text by passing a prompt as follows.

```java
String prompt = "Hi there";
String completion = palm.process(prompt);
```

To get accurate results tailored to our task, we need to provide a comprehensive and detailed prompt to the LLM, so it understand the task properly and fulfill the requirements. Few things to consider when creating our prompt:

- The prompt should be precise and clearly convey the essence of the task.
- The prompt should include any relevant context or constraints that should be considered during the text generation process. For instance, the desired style, tone, or level of complexity for the questions and answers.
- The prompt should provide any necessary instructions regarding the desired output. For instance, the number of multiple-choice questions to generate, the number of choices, etc.
- The prompt should specify the expected output format of the model, to make parsing easier.

In the following section, we will explore the output of PaLM when we provide a prompt that takes into account those considerations.

## Generating Synthetic Data with PaLM
Once we have prepared the text we want to use as context for generating our dataset examples, the next step is to create a proper prompt for the LLM. The following is an example prompt that asks the LLM to generate a multiple-choices question of 3 choices and to also provide the answer. It provides a clear explanation of the task and also provides one shot example. 

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

> Note: `{delimiter}` and `{TEXT}` are placeholders for the delimiter token and the wikipedia text respectively.


After saving the previous template in the `dataset_questions.template` file, we can pass the prompt to PaLM after setting the values to the placeholders `{delimiter}` and `{TEXT}`:

```java
String prompt = new PromptTemplate()
    .withFile("dataset_questions.template")
    .withParam("delimiter", "####")
    .withParam("TEXT", text)
    .render();
output = palm.process(prompt);
```

This is an example of output generated by PaLM:

```
question: What is the name of Odin's sword?
option_1: Gungnir
option_2: Tyrfing
option_3: Gram
answer: option_1
```

It is clear that the model is capable of carrying the task as it was able to generate a multiple-choise question with the expected format. However, the output is not easy to parse. We can do a better job by teaching the model to generate a valid one line JSON response with the following prompt:

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

Given a section from [Ibn Battuta's wikipedia page](https://en.wikipedia.org/wiki/Ibn_Battuta), the model will generate the following valid JSON object:
```
{"question": "Where did Ibn Battuta travel to after his visit to the Chagatai Khanate?", "A": "Bolghar", "B": "Constantinople", "C": "Afghanistan", "answer": "B"}
```


To validate that the model is using the given text and not making up the responses, here is an excerpt from Ibn Battuta's wikipedia page:
```
Historicity, German Islamic studies scholar Ralph Elger views Battuta's travel account as an important literary work but doubts the historicity of much of its content, which he suspects to be a work of fiction compiled and inspired from other contemporary travel reports. Various other scholars have raised similar doubts.In 1987, Ross E. Dunn similarly expressed doubts that any evidence would be found to support the narrative of the Rihla, but in 2010, Tim Mackintosh-Smith completed a multi-volume field study in dozens of the locales mentioned in the Rihla, in which he reports on previously unknown manuscripts of Islamic law kept in the archives of Al-Azhar University in Cairo that were copied by Ibn Battuta in Damascus in 1326, corroborating the date in the Rihla of his sojourn in Syria.
```

For the above input text, PaLM does a good job and generates the following multiple-choise question:

```
{"question": "What is the stance on Ibn Battuta's Rihla?", "A": "It is a work of fiction compiled from other accounts.", "B": "It is a work of fiction but with some historical details.", "C": "It is a work of history with some fictional details.", "answer": "A"}
```

After the few experiments we did earlier and the promising output of PaLM, we can confidently proceed generate a lot of questions and construct a larger dataset. But we may also try to improve the quality of the output by trying the following ideas:
- Better selection of excerpts from wikiepdia pages.
- Filter out simple and duplicate questions.
- Check the length of the requested prompt tokens and reduce it if needed.
- Improving the algorithm for randomization to delve deeper into subcategories.
- Try another LLM for multiple choice question text completion, e.g. Open AI ChatGPT.

## That's all folks
In this article we saw how easy it is to use the [LLM4J](https://llmjava.github.io/llm4j) library to interact with PaLM and build a Synsthetic Dataset Generator. We saw how to programatically query articles from Wikipedia using the [wikipedia4j](https://github.com/llmjava/wikipedia4j) library. We also saw how powerful PaLM is as it was able to follow the instructions given in our prompt and generate muliple-choices questions from an input text in the expected format.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
