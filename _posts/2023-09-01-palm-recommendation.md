---
layout: post
comments: true
title: Building an Article Recommender App in Java with llm4j, Palm and Elasticsearch
excerpt: How to Build an News article recommendation App in Java with llm4j, Palm and Elasticsearch
tags: [genai,palm,elasticsearch]
toc: true
img_excerpt:
---

![Article Recommender architecture]({{ "/assets/2023/09/20230901-palm-recommendation.svg" | absolute_url }})

In this tutorial we will see how to build a News Article Recommender app that uses PaLM (a powerful LLM from Google) for calculating text embeddings and Elasticsearch to compare between articles and find similar ones based on their embeddings. Such application is particularly useful to keep users of a newspaper (or any content platform) engaged as it recommends articles related to their reading topics.

## Design Overview
The above diagram illustrates the overall architecture of the news article recommender which we further explain here:
- The dataset of news articles is parsed from CSV.
- Using Google PaLM embed API, we calculate the embeddings for the text of each article.
- Using Google PaLM text generation API and a specific prompt template we extract the tags from each article.
- We merge the embeddings and tags into the article object and upload it to Elasticsearch
- When user selects an article, we calculate its embeddings and perfom a [KNN search](https://www.elastic.co/guide/en/elasticsearch/reference/current/knn-search.html) on Elasticsearch to find similar articles.
- The search result from  article Elasticsearch are provided as recommendations. 

The rest of this article walks through the implementation in details. 

## Setup Google PaLM using llm4j
First we create a [LanguageModel](https://llmjava.github.io/llm4j/javadoc/org/llm4j/api/LanguageModel.html) object using the [LLM4J](https://llmjava.github.io/llm4j) library. We will use this object later for text generation and embedding using Google PaLM's API.

```java
Map<String, String> configMap = new HashMap<String, String>(){{
    put("palm.apiKey", "${env:PALM_API_KEY}");
}};
Configuration config = new MapConfiguration(configMap);
LanguageModel palm = LLM4J.getLanguageModel(config, new PaLMLanguageModel.Builder());
```

> Note to connect to Google PaLM with LLM4J you need to set the environment variable `PALM_API_KEY` with the PaLM API Key that you can get from https://makersuite.google.com/app/apikey.


## Setup Elasticsearch
Next, we need to setup a connection to Elasticsearch which we will use as our Vector DB and the create an index to store (and later search) our news articles.

The following code snippet creates an [Elasticsearch client](https://www.elastic.co/guide/en/elasticsearch/client/java-api-client/current/getting-started-java.html) that can be used to interact with an Elasticsearch cluster. It takes the url of an Elasticsearch instance, as well as an API Key which can be generated from the Kibana dashboard, by default at http://localhost:5601/app/management/security/api_keys/.
```java
RestClient restClient = RestClient
    .builder(HttpHost.create(serverUrl))
    .setDefaultHeaders(new Header[]{new BasicHeader("Authorization", "ApiKey " + apiKey)})
    .build();

// Create the transport with a Jackson mapper
ElasticsearchTransport transport = new RestClientTransport(restClient, new JacksonJsonpMapper());

// And create the API client
ElasticsearchClient esClient = new ElasticsearchClient(transport);
```

Next, we use the previously initialized `ElasticsearchClient` to create an index for storing the news articles as follows.

```java
InputStream is = getClass().getClassLoader().getResourceAsStream(mappingsFile);
CreateIndexRequest request = new CreateIndexRequest.Builder()
    .index(indexName)
    .withJson(is)
    .build();
esClient.indices().create(request);
```


The following json snippet represents the mappings for our article index. It defines the different fields of an article:

- **title**: A text field to store the original title of an article.
- **text**: A text field to store the  original body of the article.
- **tags**: A keyword field to store the tags extracted from the article using PaLM.
- **embeddings**: A dense vector field to store vector embeddings of size `768` that we will generate using PaLM's embed API from the article content. It also defines `cosine` as the similarity algorithm to use when searching for similar embeddings.

```json
{
  "mappings": {
    "properties": {
      "title": { "type": "text" },
      "text": { "type": "text" },
      "tags": { "type":  "keyword" },
      "embeddings": { "type": "dense_vector", "dims": 768, "index": true, "similarity": "cosine"}
    }
  }
}
```

> Cosine similarity is a metric that measures how similar two embeddings are.

## Loading articles
Our article dataset we will be using is a subset of 100 articles from the [BBC news article dataset](http://mlg.ucd.ie/datasets/bbc.html), which consists of articles from categories like business, politics, tech, entertainment, and sports.


We’ll need to load the articles from the CSV file `bbc_news_test.csv` and create for each row an `Article` object with title and content. For this we will use the convinent [pache Commons CSV](https://commons.apache.org/proper/commons-csv/) library as follows:

```java
CSVFormat csvFormat = CSVFormat.DEFAULT
    .withFirstRecordAsHeader()
    .withIgnoreHeaderCase()
    .withDelimiter(',')
    .withQuote('"')
    .withIgnoreEmptyLines();

ClassLoader classloader = getClass().getClassLoader();
Path path = Paths.get(classloader.getResource(fileName).toURI());
CSVParser csvParser = CSVParser.parse(path, StandardCharsets.UTF_8, csvFormat);

List<Article> articles = new ArrayList<>();
for(CSVRecord csvRecord : csvParser) {
    String title = csvRecord.get("title");
    String news = csvRecord.get("news");
    Article article = new Article(title, news, Collections.emptyList());
    articles.add(article);
}

csvParser.close();
```

After pre-processing the articles we can upload the articles one by one or in bulks to Elasticsearch as follows:
```java
for(Article article: dataset) {
    IndexResponse response = esClient.index(i -> i
        .index("news")
        .id(article.getId())
        .document(article)
}
```


## Articles pre-processing
Before uploading the articles to Elasticsearch we do some pre-processing on the text of each news article to generate embeddings and extract tags using Google PaLM.

This will enrich the recommended articles with more information to help users scan the list for key information and discover content.

### Embeddings generation
Next, we’ll generate the embeddings vector for each article's using Google's PaLM Embed API like this: 

```java
String text = article.getText();
// if text too long take a subset from the right
if(text.length()>1000) {
    text = text.substring(text.length()-1000);
}
List<Float> embeddings = palm.embed(text);
```

Note that we are truncating the text by taking at most 1000 characters from the right for long articles. We need to do this as the `palm.embed` call may fail if the text is very long, which is the case for most of the news articles in this dataset. In such case PaLM will throw the following error.

```java
io.grpc.StatusRuntimeException: INVALID_ARGUMENT: Request payload size exceeds the limit: 10000 bytes
```

### Tags Extraction
We can easily build tags extractor using the Google's PaLM text generation endpoint with simple prompt engineering. Our prompt will contians few examples of text and the corresponding tags, then ask PaLM to provide a completion that contains the tags for the input text.

The following prompt template is passed to Google PaLM to extract tags for a given news article:
```
String prompt = "Given a news article, this program returns the list tags containing keywords of that article." + "\n"
                + "Article: japanese banking battle at an end japan s sumitomo mitsui financial has withdrawn its takeover offer for rival bank ufj holdings  enabling the latter to merge with mitsubishi tokyo.  sumitomo bosses told counterparts at ufj of its decision on friday  clearing the way for it to conclude a 3 trillion" + "\n"
                + "Tags: sumitomo mitsui financial, ufj holdings, mitsubishi tokyo, japanese banking" + "\n"
                + "--" + "\n"
                + "Article: france starts digital terrestrial france has become the last big european country to launch a digital terrestrial tv (dtt) service.  initially  more than a third of the population will be able to receive 14 free-to-air channels. despite the long wait for a french dtt roll-out" + "\n"
                + "Tags: france, digital terrestrial" + "\n"
                + "--" + "\n"
                + "Article: apple laptop is  greatest gadget  the apple powerbook 100 has been chosen as the greatest gadget of all time  by us magazine mobile pc.  the 1991 laptop was chosen because it was one of the first  lightweight  portable computers and helped define the layout of all future notebook pcs." + "\n"
                + "Tags: apple, apple powerbook 100, laptop" + "\n"
                + "--" + "\n"
                + "Article: " + article.text + "" + "\n"
                + "Tags:";
String rawTags = palm.process(prompt);
```

Google PaLM does a pretty good job with the extraction in most case. For instance, for the article titled `Desailly backs Blues revenge trip` it was able to infer what the news article talk about extract tags such as `chelsea, barcelona`.


## Recommendaing Articles
Finally we are ready to start recommendaing articles by simply find the most similar ones.

We sample one article from the news dataset, get its [embeddings](https://www.elastic.co/guide/en/elasticsearch/reference/current/dense-vector.html) and then ask Elasticsearch with [KNN query](https://www.elastic.co/guide/en/elasticsearch/reference/current/knn-search.html) for similar articles which have the closest embeddings.

In Java, this Elasticsearch-based recommendation query looks like this
```java
SearchRequest request = new SearchRequest.Builder()
    .index(indexName)
    .knn(builder -> builder
        .k(3)
        .numCandidates(10)
        .field("embeddings")
        .queryVector(embeddings)
    )
    .fields(new FieldAndFormat.Builder().field("title").build())
    .build();
SearchResponse<Article> response = esClient.search(request, Article.class);
```


## That's all folks
In this article we saw how easy it is to interact with LLMs like PaLM in Java using the [LLM4J](https://llmjava.github.io/llm4j) library. And how to combine the capabilities of PaLM and Elasticsearch to build an embeddings-based article recommendation solution.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
