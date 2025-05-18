---
layout: post
comments: true
title: Integrating Elasticsearch with AI agents through Model Context Protocol
excerpt: Building an Elasticsearch MCP Server for AI agents like Claude Desktop
categories: genai
tags: [elasticsearch,mcp]
toc: true
img_excerpt:
---

Large Language Models (LLMs) are getting better every day at understanding all sorts of data, but they still suffer from knowledge cut-off when dealing with data that were not part of their pre-training. By integrating LLMs with external systems and knowledge bases, LLMs could achieve their true potential as they allow users to query and analyze complex data with natural conversations. [Model Context Protol (MCP)](https://modelcontextprotocol.io/) is one way of integrating LLMs and AI assistants like Claude Desktop with external data sources. 

In this blog post, we explore how to implement an MCP server for Elasticsearch that enables Claude Desktop (or any AI Agent) to directly query and analyze data from an Elasticsearch cluster.

## What is MCP?

The Model Context Protocol (MCP) is a standardized interface that allows large language models (LLMs) like Claude to interact with external systems. It creates a bridge between AI assistants and various data stores, tools, and services while maintaining a consistent communication pattern.

As shown in the diagram, MCP enables a standardized way for AI applications to interact with:
- Data stores (databases, NoSQL databases)
- CRM systems
- Version control software
- And potentially any external service with an appropriate MCP server

## The Elasticsearch MCP Server Implementation

Let's examine the implementation provided in the `server.py` file. This Python script creates an MCP server that allows Claude to interact with an Elasticsearch cluster.

```python
from elasticsearch import Elasticsearch
from mcp.server.fastmcp import FastMCP
from typing import List

from dotenv import load_dotenv
import os

# Load .env file into the environment
load_dotenv()

def createElasticsearchClient():
    # Access environment variables
    ES_URL = os.getenv('ES_URL')
    ES_API_KEY = os.getenv('ES_API_KEY')   # base64 encoded api key
    ES_USERNAME = os.getenv('ES_USERNAME')
    ES_PASSWORD = os.getenv('ES_PASSWORD')
    ES_CA_CERT = os.getenv('ES_CA_CERT')   # path to http_ca.crt file # Optional, for HTTPS verification

    if ES_API_KEY:
        return Elasticsearch(hosts=[ES_URL], api_key=ES_API_KEY, ca_certs=ES_CA_CERT)
    if ES_USERNAME and ES_PASSWORD:
        return Elasticsearch(hosts=[ES_URL], basic_auth=(ES_USERNAME, ES_PASSWORD), ca_certs=ES_CA_CERT)
    return Elasticsearch(hosts=[ES_URL])

es = createElasticsearchClient()

# Initialize FastMCP server
mcp = FastMCP("elasticsearch-mcp-server")
```

The script begins by importing necessary libraries and setting up the Elasticsearch client connection. It supports three authentication methods:
1. API key authentication
2. Username/password authentication
3. No authentication for development environments

The server exposes three primary functions as MCP tools:

### 1. List Indices
```python
@mcp.tool()
def list_indices() -> List[str]:
    """
    List all available Elasticsearch indices.
        
    Returns:
        List of indices
    """
    indices = es.indices.get_alias(index="*")
    index_names = list(indices.keys())
    return index_names
```

This function allows Claude to retrieve all available indices in the Elasticsearch cluster.

### 2. Get Mappings
```python
@mcp.tool()
def get_mappings(index: str) -> dict:
    """
    Get field mappings for a specific Elasticsearch index.

    Args:
        index: Name of the Elasticsearch index to get mappings for

    Returns:
        Mapping schema for the specified index
    """
    mappings = es.indices.get_mapping(index=index)
    return mappings
```

This function enables Claude to understand the structure of data within a specific index by retrieving its mapping schema.

### 3. Search
```python
@mcp.tool()
def search(index: str, queryBody: dict) -> dict:
    """
    Perform an Elasticsearch search with the provided query DSL. Highlights are always enabled.

    Args:
        index: Name of the Elasticsearch index to search
        queryBody: Complete Elasticsearch query DSL object that can include query, size, from, sort, etc.

    Returns:
        Search result
    """
    response = es.search(index=index, body=queryBody)
    return response
```

This is the core function allowing Claude to execute Elasticsearch queries using the full power of the Elasticsearch Query DSL.

## Configuring Claude Desktop to Use the MCP Server

The configuration for Claude Desktop is stored in the `claude_desktop_config.json` file:

```json
{
  "mcpServers": {
    "ElasticsearchServer": {
      "command": "/opt/homebrew/bin/uv",
      "args": [
        "--directory",
        "/Applications/HOME/code/vibecoding/elasticsearch_mcp",
        "run",
        "server.py"
      ]
    }
  }
}
```

This configuration tells Claude Desktop how to launch the Elasticsearch MCP server:
1. It uses `uv` (a Python package manager/runner) to execute the server
2. It specifies the working directory where the server code is located
3. It runs the `server.py` script

## Using the Elasticsearch MCP Server with Claude

From the conversation history, we can see examples of how Claude interacts with the Elasticsearch cluster:

1. **Listing Available Indices**:
   Claude can list all available indices in the Elasticsearch cluster, which in this case reveals a single index called `hacker_news_posts`.

2. **Retrieving Mappings**:
   Claude can examine the structure of an index, showing fields like `by`, `id`, `score`, `time`, `title`, `type`, `url`, and a nested `comments` structure.

3. **Executing Search Queries**:
   Claude can run Elasticsearch queries to retrieve data, such as:
   - Searching for high-scoring posts about AI
   - Looking for posts with comments
   - Examining specific posts by ID

## Benefits of the MCP Approach

The MCP approach offers several advantages:

1. **Standardization**: MCP provides a consistent interface for LLMs to interact with external systems.

2. **Separation of Concerns**: The AI model focuses on understanding and generating responses, while the MCP server handles the specifics of interacting with the target system (in this case, Elasticsearch).

3. **Security**: Authentication details are managed by the MCP server, not exposed to the model.

4. **Extensibility**: New tools can be easily added to the MCP server without changing the core integration.

## How to Build Your Own MCP Server

If you want to create an MCP server for a different service, follow these general steps:

1. **Set up the FastMCP framework**:
   ```python
   from mcp.server.fastmcp import FastMCP
   mcp = FastMCP("your-mcp-server-name")
   ```

2. **Create client connections** to your target service.

3. **Define tool functions** using the `@mcp.tool()` decorator:
   ```python
   @mcp.tool()
   def your_function(param1: type, param2: type) -> return_type:
       """
       Document your function with clear descriptions of:
       - What it does
       - Parameters it accepts
       - What it returns
       """
       # Implementation
       return result
   ```

4. **Run the server**:
   ```python
   if __name__ == "__main__":
       mcp.run(transport='stdio')
   ```

5. **Configure Claude Desktop** to use your MCP server by updating the `claude_desktop_config.json` file.

## Conclusion

The Elasticsearch MCP server implementation demonstrates how Claude can interact with structured data in a powerful, flexible way. This enables use cases like:

- Data exploration and analysis
- Generating insights from large datasets
- Creating visualizations based on query results
- Answering complex questions about data stored in Elasticsearch

By following the MCP pattern, developers can create similar integrations for various data sources and services, expanding the capabilities of AI assistants like Claude without needing to modify the core LLM itself.

The standardization that MCP brings to AI development promises to make integrations more consistent, reliable, and easier to maintain as the AI ecosystem continues to evolve.