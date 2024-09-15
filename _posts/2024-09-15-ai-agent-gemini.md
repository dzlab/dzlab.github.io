---
layout: post
comments: true
title: AI agent from scratch with Gemini
excerpt: Build an AI agent from scratch using Gemini Function calling
categories: monitoring
tags: [genai]
toc: true
img_excerpt:
---

<img align="left" src="/assets/logos/Google_Gemini_logo.svg" width="200" />
<br/>

https://medium.com/around-the-prompt/what-are-gpt-agents-a-deep-dive-into-the-ai-interface-of-the-future-3c376dcb0824

```shell
pip install -q google-generativeai backoff
```

```python
import os
from IPython.display import display, HTML
import google.generativeai as genai
import google.ai.generativelanguage as glm
from google.api_core.exceptions import InternalServerError, TooManyRequests
import backoff
```

```python
genai.configure(api_key=os.environ['GOOGLE_API_KEY'])
```

```python
def create_folder(path):
    try:
        os.makedirs(path, exist_ok=True)
        return f"Folder created: {path}"
    except Exception as e:
        return f"Error creating folder: {str(e)}"

def create_file(path, content=""):
    try:
        with open(path, 'w') as f:
            f.write(content)
        return f"File created: {path}"
    except Exception as e:
        return f"Error creating file: {str(e)}"

def write_file(path, content):
    try:
        with open(path, 'w') as f:
            f.write(content)
        return f"Content written to file: {path}"
    except Exception as e:
        return f"Error writing to file: {str(e)}"

def read_file(path):
    try:
        with open(path, 'r') as f:
            content = f.read()
        return content
    except Exception as e:
        return f"Error reading file: {str(e)}"

def list_files(path="."):
    try:
        files = os.listdir(path)
        return "\n".join(files)
    except Exception as e:
        return f"Error listing files: {str(e)}"
```

```python
action_functions = {
    'create_folder': create_folder, # Function to create a folder
    'create_file'  : create_file,   # Function to create a file
    'write_file'   : write_file,    # Function to write to a file
    'read_file'    : read_file,     # Function to read a file
    'list_files'   : list_files,    # Function to list files in the root directory
}
```

```python
def execute_function_call(function_call, functions):
  function_name = function_call.name
  function_args = function_call.args
  if function_name not in functions:
    return f"Unknown tool: {function_name}"
  return functions[function_name](**function_args)
```

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


```python
model = genai.GenerativeModel('models/gemini-1.5-pro-latest', tools=[
    create_folder_action,
    create_file_action,
    write_file_action,
    read_file_action,
    list_files_action
    ])
```

Helper function to print colored text in Colab
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

```python
session = model.start_chat()

@backoff.on_exception(backoff.expo, (InternalServerError, TooManyRequests))
def send_message(msg):
    return session.send_message(msg)

def ask(user_input):
  # Make the initial API call
  response = send_message(user_input)

  part = response.candidates[0].content.parts[0]

  # Check if it's a function call; in real use you'd need to also handle text
  # responses as you won't know what the model will respond with.

  if part.function_call:
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
  else:
    result = part.text
  return result
```

Main loop

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

Output

```
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
```

> Node: google.api_core.exceptions.InternalServerError: 500 POST https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?%24alt=json%3Benum-encoding%3Dint: An internal error has occurred. Please retry or report in https://developers.generativeai.google/guide/troubleshooting

```shell
$ cat ./texts/hello
world
```

Resources:
- https://github.com/jggomez/gemini-workshop/blob/main/09_function_calling.py
- https://github.com/jggomez/gemini-workshop/blob/main/10_function_calling_advanced.py
- https://github.com/google-gemini/cookbook/blob/main/quickstarts/Function_calling.ipynb
- https://codelabs.developers.google.com/codelabs/gemini-function-calling

## That's all folks

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
