---
layout: post
comments: true
title: Generative AI project lifecycle
excerpt: Learn about the phases of Generative AI projects about how to plan appropriately
tags: [ai,genai]
toc: true
img_excerpt:
---

![Generative AI project lifecycle]({{ "/assets/2023/07/2023-07-30-genai-lifecycle.svg" | absolute_url }})

Generative AI is a powerful technology that has the potential to revolutionize many industries. However, generative AI projects are complex, time-consuming and involves many phases. We can increase the chances of success for such projects by following a well defined framework that maps out the tasks required to take a project from conception to launch.

In this article, we will describe a generative AI project lifecycle to help plan out the phases of a generative AI project, and provide a cheat sheet to help estimate the time and effort required for each phase of work.

## Cheat Sheet - Time and effort in the lifecycle

||Pre-training|Prompt engineering|Prompt tuning and fine-tuning|Reinforcement learning/human feedback|Compression/ optimization/ deployment|
|-|
|Training duration|Days to weeks to months|Not required|Minutes to hours|Minutes to hours similar to fine-tuning|Minutes to hours|
|Customization|{::nomarkdown}Determine model architecture, size and tokenizer.<br />Choose vocabulary size and # of tokens for input/context.<br />Large amount of domain training data{:/}|{::nomarkdown}No model weights.<br />Only prompt customization{:/}|{::nomarkdown}Tune for specific tasks.<br />Add domain-specific data.<br />Update LLM model or adapter weights{:/}|Need separate reward model to align with human goals (helpful, honest, harmless).<br />Update LLM model or adapter weights{:/}|{::nomarkdown}Reduce model size through model pruning, weight quantization, distillation.<br />Smaller size, faster inference{:/}|
|Objective|Next-token prediction|Increase task performance|Increase task performance|Increase alignment with human preferences|Increase inference performance|
|Expertise|High|Low|Medium|Medium-High|Medium|


## That's all folks
In this article we went throught the generative AI project lifecycle to build a good intuition about the important decisions to make, the potential difficulties that could be encountered, and the infrastructure needed to develop and deploy a Genrative AI application. To learn more about developping Generative AI powered applications, check this [deeplearning.ai](https://www.coursera.org/learn/generative-ai-with-llms) course.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
