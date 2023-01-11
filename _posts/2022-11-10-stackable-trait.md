---
layout: post
comments: true
title: Stackable Trait in Scala
excerpt: How to implement the Stackable Trait pattern in Scala
tags: [scala,design-pattern]
toc: true
img_excerpt:
---

<img align="center" src="/assets/logos/scala-full-color.svg" width="200" />
<br/>

I come across some old scala code that uses what turns out to be a very rare pattern in Scala called Stackable Trait. The only reference to this pattern I could find on the Internet was [this old article](https://www.artima.com/articles/scalas-stackable-trait-pattern). In this article, we will explore how it can be used with a toy example.

## Pattern
From a high level, this pattern aims to reduce the boilerplate code needed to combine multiple implmentations but:
- letting us write those implementations in different `trait`s and
- then combining their functinality by simply extenting all of those `trait`.

It can be implemented like this:

1. First, declare a base trait with the functionality we want to stack
```scala
trait T {  
  def func(): Unit = ()  
}
```

1. Then create couple of implementation traits that does different things when `func()` will be called
```scala
trait T1 extends T {
  abstract override def func(): Unit = {  
    super.func()
    // implementation here
  }
}

trait T2 extends T {
  abstract override def func(): Unit = {  
    super.func()
    // implementation here
  }
}
// more implementations
```

1. Finally, we can stack those implementation in a class like this
```scala
class T3 extends T with T1 with T2
// or class T4 extends T with T2 with T1
```
Now if we call `func()` on an instance of `T3` both implementation from `T1` and `T2` will be called in that order.

> Note how the implementation functions uses **`abstract`** and that inside them we call the parent implementation with **`super.func()`**. This subtle details is actually what makes the pattern works, If we omit one of those details it will not work.

## Example
Let's create a concrete example to better understand how this pattern works. In this example, the interfaces will simply add numbers to a queue so we could tell the order they were called.

First, we define the interfaces
```scala
trait T {  
  val queue = scala.collection.mutable.Buffer[Int]()  
  def inc(): Unit = ()  
}  
  
trait T1 extends T {  
  abstract override def inc(): Unit = {  
    super.inc()  
    queue += 1  
  }  
}  
  
trait T2 extends T {  
  abstract override def inc(): Unit = {  
    super.inc()  
    queue += 2  
  }  
}
```

Now, we create instances and call our stacked function couple times to see how it is behaving.

1. using the implementation order `T1` then `T2` 
```scala
class T3 extends T with T1 with T2

val t = new T3()
// t.queue shouldBe Seq()
t.inc()  
// t.queue shouldBe Seq(1, 2)  
t.inc()  
// t.queue shouldBe Seq(1, 2, 1, 2)
```
> Note how in this case the implementation of `T1` is called before the implementation of `T2`

1. using the implementation order `T2` then `T1` 
```scala
class T4 extends T with T2 with T1

val t = new T4()  
// t.queue shouldBe Seq()  
t.inc()  
// t.queue shouldBe Seq(2, 1)  
t.inc()  
// t.queue shouldBe Seq(2, 1, 2, 1)
```

> Note how in this case the implementation of `T2` is called before the implementation of `T1`.


## That's all folks
The Stackable trait is an interesting pattern and enables us to write cleaner code by omitting the need to write explicit code to combine multiple implementations. Hopefully from now on you can use it or when you come across it in a code you're revewing you will be able to recognize it.

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
