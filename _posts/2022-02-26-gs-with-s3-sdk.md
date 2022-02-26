---
layout: post
comments: true
title: Access Google Storage as an S3 endpoint
excerpt: How to access Google Storage as an S3 endpoint through the S3 Compatibility API.
categories: gcp
tags: gcp gs
toc: true
img_excerpt:
---

<img align="center" src="/assets/logos/icons8-google-cloud.svg" width="240" />
<br/>



Google Storage provide access thorugh different ways, one of the interesting access patterns is to considered as an S3 endpoint and access it through one of the S3 SDKs (See interoperability documentation - [link](https://cloud.google.com/storage/docs/interoperability)).

In this, article we will see how to access Google Storage using the Java S3 SDK (for Python you can refer to this article [link](https://vamsiramakrishnan.medium.com/a-study-on-using-google-cloud-storage-with-the-s3-compatibility-api-324d31b8dfeb)).


## HMAC keys

First, we need to create Access and Secret keys to use with S3 SDK. In GCP, they are called [HMAC keys](https://cloud.google.com/storage/docs/authentication/hmackeys).


<a href="https://vamsiramakrishnan.medium.com/a-study-on-using-google-cloud-storage-with-the-s3-compatibility-api-324d31b8dfeb"><img align="center" src="https://miro.medium.com/max/1400/1*bK11KEwcdOPy9U5FfIpw8w.png" /><a/>

For details refer to the steps outlined in [managing HMAC keys](https://cloud.google.com/storage/docs/authentication/managing-hmackeys) and this section [Server Side Configuration](https://vamsiramakrishnan.medium.com/a-study-on-using-google-cloud-storage-with-the-s3-compatibility-api-324d31b8dfeb).

## S3 Endpoint
Second, after creating the HMAC keys we need to get the S3 endpoint that we will use in the S3 SDK which is `https://storage.googleapis.com/`.

<a href="https://vamsiramakrishnan.medium.com/a-study-on-using-google-cloud-storage-with-the-s3-compatibility-api-324d31b8dfeb"><img align="center" src="https://miro.medium.com/max/1400/1*Mr8v9yff4u3BgkkxrmVWVg.png" /><a/>


## S3 SDK
Finally, we are ready to start using S3 SDK to access Google Storage.

We need to create an `AmazonS3` and point it to Google Storage, for instance I use the following function:

```scala
def createClient(accessKey: String, secretKey: String, region: String = "us"): AmazonS3 = {
    // create the endpoint config
    val endpointConfig = new EndpointConfiguration("https://storage.googleapis.com", region)
    // create credentials provider
    val credentials = new BasicAWSCredentials(accessKey, secretKey)
    val credentialsProvider = new AWSStaticCredentialsProvider(credentials)
    // create a client config
    val clientConfig = new ClientConfiguration()
    clientConfig.setUseGzip(true)
    clientConfig.setMaxConnections(200)
    clientConfig.setMaxErrorRetry(1)
    // create the S3 client
    val clientBuilder = AmazonS3ClientBuilder.standard()
    clientBuilder.setEndpointConfiguration(endpointConfig)
    clientBuilder.withCredentials(credentialsProvider)
    clientBuilder.withClientConfiguration(clientConfig)
    clientBuilder.build()
}
```

Now, we can create a client
```scala
val client = createClient(ACCESS_KEY, SECRET_KEY, REGION)
```

To list Google storage buckets we can simply use S3's `listBuckets`

```scala
val buckets = client.listBuckets()
```

To initiate multi-part uploads we can simply use S3's `initiateMultipartUpload`
```scala
val multipartUploadRequest = new InitiateMultipartUploadRequest(bucket, key)
client.initiateMultipartUpload(multipartUploadRequest).getUploadId
```

## That's all folks

Feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc)