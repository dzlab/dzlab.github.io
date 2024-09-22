---
layout: post
comments: true
title: AI agent from scratch with Gemini
excerpt: Build an AI agent from scratch using Gemini Function calling
categories: genai
tags: [agent]
toc: true
img_excerpt:
---

<img align="center" src="/assets/logos/Google_Gemini_logo.svg" width="200" />
<br/>


LLMs like [Google Gemini](https://gemini.google.com/) takes input for a single query and returns an output (e.g. text, image or audio), it cannot do more than a single task at a time. On the other hand, an Agent run iteratively with some goals / tasks defined. An agent uses complex workflows; it continusouly talks to the LLM without a human interaction until it reaches its goal.

With the introduction of [Function Calling](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/function-calling), Gemini can make use of external tools by outputting a well formatted output that matches the input expected. This capability is a first manifestation of the “agents” idea inside of Gemini as now the model can make the decision on whether to use the tools at hand and which one.

In the rest of this article, we will use Gemini's Function Calling to build a simple FileSystem Agent from scratch. The main components of our agent implementation are:
- **Tool dispatching:** This component is reponsible of executing the right tool based on the LLM reponse.
- **Task planning:** This component leaverages the LLM Gemini to reason about the user query and respond to it with the appropriate a function call.
- **Agent orchestration:** This component implements the agent main loop, it listen to user query, forwards them to the task planner, and then uses the tool dispatching component to execute tools.

> Note: Agent workflows may require a lot of interactions with the LLM, and as a result may cause a lot of API usage which may not be free of charge.


## Setup
First, let's install some dependencies. We will need the [backoff](https://github.com/litl/backoff) to implement retries for Gemini API as the agent will cause the Rate limit to be reached quickly.

```shell
pip install -q google-generativeai backoff
```

Import packages

```python
import os
from IPython.display import display, HTML
import google.generativeai as genai
import google.ai.generativelanguage as glm
from google.api_core.exceptions import InternalServerError, TooManyRequests
import backoff
```

Setup Gemini API Key

```python
genai.configure(api_key=os.environ['GOOGLE_API_KEY'])
```

Define a helper function to print colored text

```python
def print_colored(text, color):
    color_map = {
        'blue': '#3366cc',
        'yellow': '#ffcc00',
        'green': '#33cc33',
        'white': '#ffffff'
    }
    html_color = color_map.get(color.lower(), '#000000')  # Default to black if color not found
    display(HTML(f'<pre style="color: {html_color};">{text}</pre>'))
```

## Tool dispatching

We define the tools or external APIs that the agent will be executing as instructed by the LLM. In our case, these APIs perform operations on the local Filesystem. e.g. create folder, write file, etc.

```python
# Create a folder at the given path
def create_folder(path):
    try:
        os.makedirs(path, exist_ok=True)
        return f"Folder created: {path}"
    except Exception as e:
        return f"Error creating folder: {str(e)}"

# Create a file at the given path and optionnally write the content into it
def create_file(path, content=""):
    try:
        with open(path, 'w') as f:
            f.write(content)
        return f"File created: {path}"
    except Exception as e:
        return f"Error creating file: {str(e)}"

# Write content to a file
def write_file(path, content):
    try:
        with open(path, 'w') as f:
            f.write(content)
        return f"Content written to file: {path}"
    except Exception as e:
        return f"Error writing to file: {str(e)}"

# Read content of a file
def read_file(path):
    try:
        with open(path, 'r') as f:
            content = f.read()
        return content
    except Exception as e:
        return f"Error reading file: {str(e)}"

# List files at given location
def list_files(path="."):
    try:
        files = os.listdir(path)
        return "\n".join(files)
    except Exception as e:
        return f"Error listing files: {str(e)}"
```

To easily locate our functions by name, we group them into a dictionary that we will use later:

```python
action_functions = {
    'create_folder': create_folder, # Function to create a folder
    'create_file'  : create_file,   # Function to create a file
    'write_file'   : write_file,    # Function to write to a file
    'read_file'    : read_file,     # Function to read a file
    'list_files'   : list_files,    # Function to list files in the root directory
}
```

The following is a helper function dispatches the Function Call returned by the LLM to the right tool. First, we locate the right tool and then call it.

```python
def execute_function_call(function_call, functions):
  function_name = function_call.name
  function_args = function_call.args
  if function_name not in functions:
    return f"Unknown tool: {function_name}"
  return functions[function_name](**function_args)
```

## Task planning

Task planning configures Gemini Function Calling with a list of tools. It declares each exposed tool using Gemini's function schema by providing a description of the tool and its list of parameters.

Below are the definitions of our Filesystem tools:

```python
create_folder_action = {'function_declarations': [
    {'name': 'create_folder',
     'description': 'Create a new folder at the specified path.',
     'parameters': {
         'type_': 'OBJECT',
         'properties': {
             'path': {
                 'type_': 'STRING',
                 'description': 'The path where the folder should be created'},
             },
         'required': ['path']}}
]}
create_file_action = {'function_declarations': [
    {'name': 'create_file',
     'description': 'Create a new file at the specified path with optionally provided content.',
     'parameters': {
         'type_': 'OBJECT',
         'properties': {
             'path': {
                 'type_': 'STRING',
                 'description': 'The path where the file should be created'},
             'content': {
                 'type_': 'STRING',
                 'description': 'The content of the file to be created'},
             },
         'required': ['path']}}
]}
write_file_action = {'function_declarations': [
    {'name': 'write_file',
     'description': 'Write content to an existing file at the specified path.',
     'parameters': {
         'type_': 'OBJECT',
         'properties': {
             'path': {
                 'type_': 'STRING',
                 'description': 'The path of the file to write to'},
             'content': {
                 'type_': 'STRING',
                 'description': 'The content to write to the file'},
             },
         'required': ['path', 'content']}}
]}
read_file_action = {'function_declarations': [
    {'name': 'read_file',
     'description': 'Read the content of an existing file at the specified path.',
     'parameters': {
         'type_': 'OBJECT',
         'properties': {
             'path': {
                 'type_': 'STRING',
                 'description': 'The path of the file to read from'},
             },
         'required': ['path']}}
]}
list_files_action = {'function_declarations': [
    {'name': 'list_files',
     'description': 'List files of the folder at the specified path.',
     'parameters': {
         'type_': 'OBJECT',
         'properties': {
             'path': {
                 'type_': 'STRING',
                 'description': 'The path of the folder to list its files'},
             },
         'required': []}}
]}
```

Now, we configure Gemini with the list of our tools as follows:

```python
model = genai.GenerativeModel('models/gemini-1.5-pro-latest', tools=[
    create_folder_action,
    create_file_action,
    write_file_action,
    read_file_action,
    list_files_action
    ])
```

## Agent orchestration
This section details the implementation of the Agent orchestration, where we orchestrates the interactions with the user, the LLM and the tools.

First, let's create a helper function to submit requests to Gemini

```python
session = model.start_chat()

@backoff.on_exception(backoff.expo, (InternalServerError, TooManyRequests))
def send_message(msg):
    return session.send_message(msg)
```

Note the use of the [Exponential backoff](https://en.wikipedia.org/wiki/Exponential_backoff) strategy when calling Gemini API so that we automatically retry with backoff when we hit the rate limit for API call. In fact, Gemini would trigger the following exception:

```
google.api_core.exceptions.InternalServerError: 500 POST https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?%24alt=json%3Benum-encoding%3Dint: An internal error has occurred. Please retry or report in https://developers.generativeai.google/guide/troubleshooting
```

Second, we define an orchestration helper function that takes user queries, call the task planner with this input, forward the planned task to the dispatcher, then sends back the tool response to the LLM, and finally return the final result to the user.

```python
def ask(user_input):
  # Make the initial API call
  response = send_message(user_input)

  part = response.candidates[0].content.parts[0]

  # Check if it's a function call otherwise simply return the LLM response
  if not part.function_call:
    result = part.text
  else:
    function_result = execute_function_call(part.function_call, action_functions)
    # Send the function response back to the model
    response = send_message(
        glm.Content(
            parts=[glm.Part(
            function_response=glm.FunctionResponse(
                name=part.function_call.name,
                response={'result': function_result}))]
            )
        )
    result = response.text

  return result
```

Finally, we define the Main loop that indefinitely asks the user for queries, plan and execute the corresponding task, then return the result to the user.

```python
print_colored("Welcome to the AI Agent Chat!", "blue")
print_colored("Type 'exit' to end the conversation.", "blue")

while True:
  user_input = input("\nYou: ")
  if user_input.lower() == 'exit':
    print_colored("Thank you for chatting. Goodbye!", "blue")
    break

  response = ask(user_input)
  print_colored(f"AI: {response}", "green")
```


## Testing the Agent
The folloing is an example conversation between a user trying to execute some basic Filesystem actions and our Gemini-based Agent:

<pre style="color: #3366cc;">
Welcome to the AI Agent Chat!
Type 'exit' to end the conversation.

You: create a folder texts under current directory
AI: OK, I've created the folder `texts` under the current directory. 

You: list the files and folders under current directory
AI: Here are the files and folders under the current directory:

'''
.config
texts
sample_data
'''

You: create a file named hello under directory texts
AI: OK, I've created the file `hello` under the `texts` directory. 

You: write string world into the file at ./texts/hello
AI: OK. I've written "world" to the file `texts/hello`. 

You: paste here the content of texts/hello
AI: The content of `texts/hello` is:

'''
world
'''

You: exit
Thank you for chatting. Goodbye!
</pre>

We can manually check that the file was created a the right place and with the right content:

```shell
$ cat ./texts/hello
world
```

## That's all folks

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
