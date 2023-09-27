---
layout: post
comments: true
title: RESTful web services in Scala 3 using ZIO
excerpt: How to create RESTful web services in Scala 3 with ZIO
tags: [scala,zio]
toc: true
img_excerpt:
---

<img align="center" src="/assets/logos/zio.png" width="480" />
<br/>


In ZIO, an HTTP service is defined by extending the `zio.http.Http` trait:

```scala
trait Http[-R, +E, -A, +B] extends (A => ZIO[R, Option[E], B])
```

A `Http[R, E, A, B]` is a function that takes an `A` and returns a `ZIO[R, Option[E], B]`. More specifically, it:

- Uses the `R` from the environment
- Will fail with `E` if there is an error
- Accepts an `A` and returns `B`

In the rest of this article, we will see how to create different types of HTTP service with the following ZIO libraries:

- [ZIO HTTP](https://zio.dev/zio-http/) for creating HTTP servers
- [ZIO JSON](https://zio.dev/zio-json/) for JSON serialization

Let's first define the dependencies in `build.sbt`:
```scala
scalaVersion := "3.3.1"

libraryDependencies ++= Seq(
  "dev.zio" %% "zio" % "2.0.18",
  "dev.zio" %% "zio-json" % "0.6.2",
  "dev.zio" %% "zio-http" % "3.0.0-RC2"
)
```

And also define our application main entrypoint.
```scala
object MainApp extends ZIOAppDefault:
  def run: ZIO[Environment with ZIOAppArgs with Scope, Throwable, Any] =
    val httpServices = StatelessService() ++ FileService() ++ StatefulService()
    Server
      .serve(httpServices.withDefaultErrorResponse)
      .provide(Server.defaultWithPort(8080), InmemoryItemRepo.layer)
```

In the following sections we will define the different services used earlier: `StatelessService`, `FileService`, `StatefulService`.

## Stateless service
This is a simple HTTP service that extends `Http[Any, Nothing, Request, Response]`, it doesn't require any services from the environment (`Any`), doesn't fail `Nothing`. It takes a request `Request` and Returns a response `Response`.

It exposes the following endpoints
1. `GET /greet` that returns a simple string response
2. `GET /greet/:name` that expects a parameter in the URL and returns a string response
3. `GET /greet?name=a&name=b` it extracts every `name` parameter from the query parameters

```scala
object StatelessService {
  def apply(): Http[Any, Nothing, Request, Response] =
    Http.collect[Request] {

      // GET /greet?name=:name
      case req @ (Method.GET -> Root / "greet")
        if (req.url.queryParams.nonEmpty) =>
          Response.text(s"Hello ${req.url.queryParams.get("name").map(_.mkString(" and "))}!")

      // GET /greet
      case Method.GET -> Root / "greet" => Response.text(s"Hello World!")

      // GET /greet/:name
      case Method.GET -> Root / "greet" / name => Response.text(s"Hello $name!")
    }
}
```

## File service
This is an HTTP service that extends `Http[Any, Throwable, Request, Response]`, it doesn't require any environment, it may fail with `Throwable` error and it consumes a `Request` and produces a `Response` respectively.

It exposes the following endpoints
1. `GET /download` which downloads a file named `file.txt`
2. `GET /download/stream` which streams the chunks of the large file named `bigfile.txt`

```scala
object FileService {
  def apply(): Http[Any, Throwable, Request, Response] =
    Http.collect[Request] {

      // GET /download
      case Method.GET -> Root / "download" =>
        val fileName = "file.txt"
        http.Response(
          status = Status.Ok,
          headers = Headers(
            Header.ContentType(MediaType.application.`octet-stream`),
            Header.ContentDisposition.attachment(fileName)
          ),
          body = Body.fromStream(ZStream.fromResource(fileName))
        )

      // Download a large file using streams
      // GET /download/stream
      case Method.GET -> Root / "download" / "stream" =>
        val file = "bigfile.txt"
        http.Response(
          status = Status.Ok,
          headers = Headers(
            Header.ContentType(MediaType.application.`octet-stream`),
            Header.ContentDisposition.attachment(file)
          ),
          body = Body.fromStream(ZStream.fromResource(file).schedule(Schedule.spaced(50.millis)))
        )
    }
}
```


## Stateful service
This is an HTTP service that extends `Http[ItemRepo, Throwable, Request, Response]`. It requires a `ItemRepo` service from the ZIO environment, it can fail with `Throwable` error. It consumes a `Request` and produces a `Response` respectively.

It exposes the following endpoints
1. `POST /items` expects a JSON paylod representing a new item to store
1. `GET /items` to list all previously inserted items in JSON
1. `GET /items/:id` to get a JSON representation of an item by its identifier

Implementing this service is more involed, we first need to define our data model `Item` and its JSON de/serialization logic in `Item.scala`

```scala
case class Item(name: String, desription: String)

object Item:
  given JsonEncoder[Item] = DeriveJsonEncoder.gen[Item]
  given JsonDecoder[Item] = DeriveJsonDecoder.gen[Item]
```

Then, we define the interfaces for registering/searching/listing items in a `ItemRepo` trait along with the corresponding ZIO zervice in `ItemRepo.scala`:

```scala
trait ItemRepo:
  def insert(item: Item): Task[String]
  def lookup(id: String): Task[Option[Item]]
  def items: Task[List[Item]]

object ItemRepo:
  def insert(item: Item): ZIO[ItemRepo, Throwable, String] = ZIO.serviceWithZIO[ItemRepo](_.insert(item))
  def lookup(id: String): ZIO[ItemRepo, Throwable, Option[Item]] = ZIO.serviceWithZIO[ItemRepo](_.lookup(id))
  def items: ZIO[ItemRepo, Throwable, List[Item]] = ZIO.serviceWithZIO[ItemRepo](_.items)
```

Then we define an in-memory implementation of `ItemRepo` and register it to ZIO environemnt in `InmemoryItemRepo.scala`:

```scala
case class InmemoryItemRepo(map: Ref[Map[String, Item]]) extends ItemRepo:
  def insert(item: Item): UIO[String] =
    for
      id <- Random.nextUUID.map(_.toString)
      _  <- map.update(_ + (id -> item))
    yield id

  def lookup(id: String): UIO[Option[Item]] = map.get.map(_.get(id))
  def items: UIO[List[Item]] = map.get.map(_.values.toList)

object InmemoryItemRepo {
  def layer: ZLayer[Any, Nothing, InmemoryItemRepo] =
    ZLayer.fromZIO(
      Ref.make(Map.empty[String, Item]).map(new InmemoryItemRepo(_))
    )
}
```

Finally, we implement our HTTP service and expose the different endpoints
```scala
object StatefulService {
  def apply(): Http[ItemRepo, Throwable, Request, Response] =
    Http.collectZIO[Request] {

      // POST /items -d '{"name": "...", "description": "..."}'
      case req @ (Method.POST -> Root / "items") =>
        (for {
          i <- req.body.asString.map(_.fromJson[Item])
          r <- i match
            case Left(e) =>
              ZIO.debug(s"Failed to parse the input: $e")
                .as(Response.text(e).withStatus(Status.BadRequest))
            case Right(i) =>
              ItemRepo.insert(i).map(id => Response.text(id))
        } yield r).orDie

      // GET /items/:id
      case Method.GET -> Root / "items" / id =>
        ItemRepo
          .lookup(id)
          .map {
            case Some(item) => Response.json(item.toJson)
            case None => Response.status(Status.NotFound)
          }
          .orDie

      // GET /items
      case Method.GET -> Root / "items" =>
        ItemRepo.items.map(response => Response.json(response.toJson)).orDie
    }
}
```

## That's all folks
In this article we saw how easy it is to work with [ZIO](https://zio.dev) ecosystem to build HTTP services for different use cases.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
