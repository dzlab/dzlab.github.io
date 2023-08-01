---
layout: post
comments: true
title: Generative AI project lifecycle
excerpt: Learn about the phases of Generative AI projects about how to plan appropriately
tags: [ai,genai]
toc: true
img_excerpt:
---

Generative AI is a powerful technology that has the potential to revolutionize many industries. However, generative AI projects are complex, time-consuming and involves many phases. We can increase the chances of success for such projects by following a well defined framework that maps out the tasks required to take a project from conception to launch.

In this article, we will describe a generative AI project lifecycle to help plan out the phases of a generative AI project, and provide a cheat sheet to help estimate the time and effort required to carry out each phase of work.

## Project lifecycle
The below diagram highlights the different phases of the lifecycle of a Generative AI project. In the rest of this section we will go over each phase.

![Generative AI project lifecycle]({{ "/assets/2023/07/2023-07-30-genai-lifecycle.svg" | absolute_url }})
Credit [deeplearning.ai](https://www.coursera.org/learn/generative-ai-with-llms)

### Scoping
As with any project, scoping accurately and narrowly the use case, goals and objectives is the most import step. In the case of Generative AI projects, scoping is about defining the model requirements for a specific use case and budget.

Getting really specific about what the model need to perform can save time and compute cost. In fact, LLMs are capable of carrying out many tasks, but their performance and runtime cose depend strongly on the size and architecture. So, we need think about what tasks the LLM will have in our specific application.

An example question to ask to help scoping, is do we need the model to be able to perform very well on many different tasks (e.g. text generation, summarizatin, translation, etc.), or instead we need the model to be very good at one specific task (e.g. named entity recognition). 

### Model Selection
Once we are done with scoping the model requirements. We need to decide whether we can simply work with an existing base model or instead we need to train our own model from scratch. The best practice is to start with an existing model, and assess its performance and carry out additional training if needed for your application.

Although there are some cases where it can be necessary to train a model from scratch. In this case, there are some considerations to take into account (e.g. task domain), as well as some rules of thumb to estimate the feasibility of training our own model.

A good example of pre-training a model from scratch for increased domain-specificity is the [BloombergGPT](https://arxiv.org/abs/2303.17564) project, developed by [Bloomberg](https://bloomberg.com/). This model was pre-trained using an extensive financial dataset comprising news articles, reports, and market data, to increase its understanding of finance and enabling it to generate finance-related natural language text.

### Model Alignment

In many cases, prompt engineering (and in particular in-context learning) can be enough to get an LLM model to perform well. This is achieved by providing the model with one or few shots/examples to describe the task and expected answer, then assessing the model performance.

However, there are cases where the model may perform poorly in the task at hand, and fine-tuning becomes necessary. One typical approach, is to use a supervised learning process to adapt the model. Another LLM-specific approach is Reinforcement Learning with Human Feedback (RLHF), which can help to make sure that the model behaves well and in a way that is aligned with human preferences. In both approaches, we would need to collect data that is relevant to the task. For the fine-tuning to be effective, we need to make sure data is of high quality by cleaning it, removing any errors or inconsistencies, and formatting it in a way that the model can understand.

Note that this adapt and aligned stage is highly iterative and requires back and forth. We may start with prompt engineering and evaluating the outputs, then using fine tuning to improve performance and then revisiting and evaluating prompt engineering one more time to get an acceptable performance level.

To determine how well a model is performing or how well aligned it is to our preferences, we can use classical NLP evaluation techniques like metrics (e.g. ROUGE and BLEU Score) and benchmarks (e.g. GLUE).

### Application integration

Once the model is meeting the performance expectations and is properly aligned, it becomes ready for deploylement and integration with the application. But, we should not deploy it as is just yet. Instead, we should explore ways to optimize the model for deployment to ensure that we are making the best use of our compute resources and still providing the best possible experience to all users of the application. Example model optimization techniques that proved to work well for LLMs are Distillation, Post-training quantization and pruning.

It is important to note that there are some fundamental limitations of LLMs even if they performs well during their initial training. Example of such limitations inlucde how their information can become outdated, tendency to invent information when they don't know an answer (also known as hallucination), or their limited ability to carry out complex reasoning and mathematics.

Those limitations can be overcome by some powerful techniques like:
- Retrieval augmented generation (RAG) which aims to augment the model knowlege with external data sources (e.g. wikipedia for fact checking).
- Chain-of-Thought Prompting: which can be achieved by tweaking the prompt given to the model to include few shots with reasoning instructions.
- Program-aided Language (PAL) models which aims to integrate the LLM with third-party applications, python interpreter to execute complex reasoning logic, or SQL interpreter to execute SQL queries generate by the model.

However, it is important to consider the additional infrastructure and cost that your application will require augment the model at inference.

## Time and effort estimation

||Pre-training|Prompt engineering|Prompt tuning and fine-tuning|Reinforcement learning/human feedback|Compression/ optimization/ deployment|
|-|
|Training duration|Days to weeks to months|Not required|Minutes to hours|Minutes to hours similar to fine-tuning|Minutes to hours|
|Customization|{::nomarkdown}Determine model architecture, size and tokenizer.<br />Choose vocabulary size and # of tokens for input/context.<br />Large amount of domain training data{:/}|{::nomarkdown}No model weights.<br />Only prompt customization{:/}|{::nomarkdown}Tune for specific tasks.<br />Add domain-specific data.<br />Update LLM model or adapter weights{:/}|Need separate reward model to align with human goals (helpful, honest, harmless).<br />Update LLM model or adapter weights{:/}|{::nomarkdown}Reduce model size through model pruning, weight quantization, distillation.<br />Smaller size, faster inference{:/}|
|Objective|Next-token prediction|Increase task performance|Increase task performance|Increase alignment with human preferences|Increase inference performance|
|Expertise|High|Low|Medium|Medium-High|Medium|


## That's all folks
In this article we went throught the generative AI project lifecycle to build a good intuition about the important decisions to make, the potential difficulties that could be encountered, and the infrastructure needed to develop and deploy a Genrative AI application.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
