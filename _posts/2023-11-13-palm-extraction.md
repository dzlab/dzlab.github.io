---
layout: post
comments: true
title: Extracting structured data from unstructured text with PaLM
excerpt: PaLM example showing how to extract detailed job description from unstructured text taken from HN 'Who is Hiring?' tread
tags: [genai,palm]
toc: true
img_excerpt:
---

In this article, we'll go over one of the main use cases that LLMs like PaLM are used for, which is extracting specific entities from unstructured text. These entities are represented by a structured description of multiple pieces of information, and the LLM to look over the text and extract a list of these elements at once. For instance, we might ask the LLM to look over an article and extract a list of the papers that were referenced in that article.

In the rest of this article, we will use PaLM to extract and organize job posting from Hacker News 'Who is Hiring?' tread.


First, install PaLM python library and set PaLM API Key
```bash
pip install google-generativeai
export GOOGLE_API_KEY=xyz
```

Then, import needed modules

```python
import os
import json
import requests
import google.generativeai as palm
```

Initialise PaLM with the API Key
```python
palm.configure(api_key=os.environ['GOOGLE_API_KEY'])
```

Then, we use Hacker News Algolia Search API to retrieve all the comments from the HN thread. For example, November thread URL is https://news.ycombinator.com/item?id=38099086 and can be accessed throught Algolia Search API at https://hn.algolia.com/api/v1/search_by_date?tags=comment,story_38099086&hitsPerPage=3

```python
endpoint = 'https://hn.algolia.com/api/v1/search_by_date'
thread_id = '38099086'
url = f'{endpoint}?tags=comment,story_{thread_id}&hitsPerPage=3'

response_raw = requests.get(url)
response = json.loads(response_raw.text)
```

The response contains an array of JSON objects within the `hits` field, each representing a post from the HN thread. In our case, we need the `comment_text` field of the comment objects as they do contain the actual text of each comment. We extract them like this

```python
posts = []
for hit in response['hits']:
    if hit['parent_id'] == hit['story_id']:
        post = {'created_at': hit['created_at'], 'author': hit['author'], 'description': hit['comment_text']}
        posts.append(post)
```

Notice that by using the condition `hit['parent_id'] == hit['story_id']` we are ignore comments that are not top level, are not actual job description.

we can examine some of the job description with

```python
description = posts[0]['description']
description
```

This will return something like

```
Doist | Platform Engineer | Remote-first | Full-time | Learn more &amp; apply (through November 14): <a href="https:&#x2F;&#x2F;doist.com&#x2F;careers&#x2F;86E3FE7734-platform-engineer" rel="nofollow noreferrer">https:&#x2F;&#x2F;doist.com&#x2F;careers&#x2F;86E3FE7734-platform-engineer</a><p>Doist | iOS Engineer | Remote-first | Full-time | Learn more &amp; apply (through Novemver 27): <a href="https:&#x2F;&#x2F;doist.com&#x2F;careers&#x2F;296CCEE773-ios-engineer" rel="nofollow noreferrer">https:&#x2F;&#x2F;doist.com&#x2F;careers&#x2F;296CCEE773-ios-engineer</a><p>At Doist, we&#x27;re building the future of work.<p>We envision a future in which people can work without distractions from anywhere in the world on things that they are passionate about and then unplug at the end of the day with the reassuring peace-of-mind that their tasks and teamwork are accounted for.<p>All our roles are fully remote, so you&#x27;ll be free to work from wherever you please and on a schedule that works best for you.<p>To learn more about who we are and how we work, please check out our blog: <a href="https:&#x2F;&#x2F;blog.doist.com&#x2F;" rel="nofollow noreferrer">https:&#x2F;&#x2F;blog.doist.com&#x2F;</a>
```

From the above text, we want to extract the pieces of information that describe the job like company name and job location, etc. Let's define the schema or list of fields we want PaLM to extract from each raw job description: 

```python
fields = """
    - Company
    - Goal
    - Positions
    - Locations
    - Job Type: Full time or part time
    - Remote (Full, Partial, from specific timezone)
    - Compensation
    - Experience
    - Website URL
    - Job offer URLs
    - Emails
    - Visa
"""
```

Then we define a general template for the prompt we will submit to PaLM for it to perform the extraction task:

```python
prompt_template = """
You will be provided with a Job description enclosed between ####.
The job description is taken from 'Ask HN: Who is Hiring?' and may contain HTML tags.

Extract from it the following key points (use null if needed):{fields}

If you encouter any concealed email address then decipher.
Format the output as a valid JSON object. 

####
{description}
####
"""
```

Now, we simply iterate through each post in the thread, construct the prompt and then submit it to PaLM:

```python
jobs = []
for post in posts:
    prompt = prompt_template.format(fields=fields, description=post['description'])
    completion = palm.generate_text(
        model=model,
        prompt=prompt,
        temperature=0,
        candidate_count=1,
        max_output_tokens=1024,
    )
    job = json.loads(completion.result)
    jobs.append(job)
```

This is an example job description as returned by PaLM

```
{'Company': 'Doist', 'Goal': 'Building the future of work', 'Positions': ['Platform Engineer', 'iOS Engineer'], 'Locations': ['Remote-first'], 'Job Type': 'Full-time', 'Remote': 'Full', 'Compensation': None, 'Experience': None, 'Website URL': 'https://doist.com/', 'Job offer URLs': ['https://doist.com/careers/86E3FE7734-platform-engineer', 'https://doist.com/careers/296CCEE773-ios-engineer'], 'Emails': None, 'Visa': None}
```

As an improvement, we can play further with the prompt to make sure the output of PaLM is valid JSON and that each field data type is consistent with an expected schema. For instance when using a field named `Location`, PaLM will tend to return only one value, but as we used `Locations` it seemed to have understood that we want a list and does a good job in following this. But still there are cases where sometimes it will return a string and another time it will return an integer. One thing we can try is to add a description of the expected type next to each field definition in the prompt.


## That's all folks
Structured data extraction is one of the most popular use cases for using LLM. And so gaining familiarity with this task will go a long way. In this article, we saw how to leverage the capabilities of Algolia API to load data from Hacker News and use PaLM for data processing and extraction to converts a raw thread text into a structured and organized list of job descriptions.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
