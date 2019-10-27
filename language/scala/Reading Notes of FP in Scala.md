---
typora-copy-images-to: ../scala
---

[TOC]

## BOOK
https://learning.oreilly.com/library/view/functional-programming-in/9781617290657/kindle_split_014.html



###  Chapter 7

好南南。。。。。

例子：如何并行化序列求和









### Chapter 6


以随机数生成为例，传统的Java的random方法里，每次调用会改变内部Random seed的值，使得方法不具备refrence transparent.

可以通过，把变化的seed作为传参的方式将random改写。
```
Don’t update the state as a side effect, but simply return the new state along with the value that we’re generating.
```

核心还是把函数逻辑保持稳定，分析变与不变，变换的东西抽离出函数实现，作为一个参数传入。

第一次 Rand(5)  -> Rand (State1, 5) 产生State2, 其中 State2 包含了新的seed

第二次 Rand(5)  -> Rand(State2, 5)



### Chapter 5 惰性求值

 >Non-strictness is a property of a function. To say a function is non-strict just means that the function may choose *not* to evaluate one or more of its arguments. In con- trast, a *strict* function always evaluates its arguments. 

#### strictness sample

```scala
def square(x: Double): Double = x * x
```

When you invoke square(41.0 + 1.0), the function square will receive the evaluated
value of 42.0 because it’s strict. If you invoke square(sys.error("failure")), you’ll
get an exception before square has a chance to do anything, since the sys.error
("failure") expression will be evaluated before entering the body of square.

#### non-strictness sample

The function && takes two Boolean arguments, but only evaluates the
second argument if the first is true

```scala
scala> false && { println("!!"); true } // does not print anything
res0: Boolean = false
```



In Scala, we can write **non-strict functions** by **accepting some of our arguments**
**unevaluated.** We’ll show how this is done explicitly just to illustrate what’s happening,
and then show some nicer syntax for it that’s built into Scala. Here’s a non-strict if
function:

```scala
def if2[A](cond: Boolean, onTrue: () => A, onFalse: () => A): A =
    if (cond) onTrue() else onFalse()
```

onTrue & onFalse是两个无参函数输入，这两个参数即non-strict参数

The arguments we’d like to pass unevaluated have a () => immediately before their
type. In general, the unevaluated form of an expression is called a *thunk*, and we can *force*
the thunk to evaluate the expression and get a result. We do so by invoking the func-
tion, passing an empty argument list, as in onTrue() or onFalse()

we’re passing a function of no arguments in place of each non-strict parameter, and then explicitly calling this function to obtain a result in the body.

 if2在scala中可以直接简写成

 ```scala
def if2[A](cond: Boolean, onTrue: => A, onFalse: => A): A =
    if (cond) onTrue else onFalse

 ```

![屏幕快照 2019-09-29 下午12.44.02](/Users/yoga/Documents/workspace/review/scala/屏幕快照 2019-09-29 下午12.44.02.png)

#### laziness

简单的两次函数调用触发两次print

```scala
scala> def maybeTwice(b: Boolean, i: => Int) = if (b) i+i else 0
maybeTwice: (b: Boolean, i: => Int)Int

scala> val x = maybeTwice(true, { println("hi"); 1+41 })
hi
hi
x: Int = 84
```
通过lazy引入thunk, **j 变成惰性求值，延后并cache计算结果**
```
scala> def maybeTwice2(b: Boolean, i: => Int) = {
     |   lazy val j = i
     |   if (b) j+j else 0
     | }
maybeTwice: (b: Boolean, i: => Int)Int

scala> val x = maybeTwice2(true, { println("hi"); 1+41 })
hi
x: Int = 84
```
再将lazy应用到List Cons中 ->Stream,这样原来的一段 list 的操作链 可转换成stream的操作链
- list.filter.map.take.xx.print ： 在原List中，每个action都是即时触发的，每个结果都会生成一个中间计算结
- stream.filer.map.take.xxx.printS: 操作链实际变成了一连串的层层嵌套的thunk链， thunk1 -> thunk2 -> thunk3 -> thunk4, 而最后一个实际访问的其中元素的操作，比如printS 上的 **print(h())** 中的**h()** 来触发当前元素的整个操作链的执行。
```
stream match {
   Cons(h, t) => {print(h()); printS(t())}
   Empty => println()
}
```
![streaming-chain](https://raw.githubusercontent.com/fuqiliang/review/master/scala/c5_stream_chain.png)
应用这个特性，甚至可以定义无穷，在无穷上做操作，神奇！

```
val ones: Stream[Int] = Stream.cons(1, ones)
scala> ones.take(5).toList
res0: List[Int] = List(1, 1, 1, 1, 1)

scala> ones.exists(_ % 2 != 0)
res1: Boolean = true
```

![inifinate](https://raw.githubusercontent.com/fuqiliang/review/master/scala/c5_one.png)



### Chapter 4 异常处理Option&Either

```
sealed trait Option[+A]
case class Some[+A](get: A) extends Option[A]
case object None extends Option[Nothing]

```

```
sealed trait Either[+E, +A]
case class Left[+E](value: E) extends Either[E, Nothing]
case class Right[+A](value: A) extends Either[Nothing, A]
```

### Chapter 3

>  functional data structures are by definition immutable. 
>  Doesn’t this mean we end up doing a lot of extra copying of the data? Perhaps surprisingly, the answer is no.

![data sharing](https://raw.githubusercontent.com/fuqiliang/review/master/scala/c2_data_sharing.png)

#### Sealed

> 1. 其修饰的trait，class只能在**当前文件里面被继承**；
> 2. 在检查模式匹配的时候，用sealed修饰目的是让scala知道这些case的所有情况，scala就能够在编译的时候进行检查，看你写的代码是否有没有漏掉什么没case到，减少编程的错误

#### foldRight & foldLeft

```scala
def foldRight[A,B](as: List[A], z: B)(f: (A, B) => B): B = // Utility functions
    as match {
      case Nil => z
      case Cons(x, xs) => f(x, foldRight(xs, z)(f))
}

def sum2(ns: List[Int]) =  foldRight(ns, 0)((x,y) => x + y)

@annotation.tailrec
def foldLeft[A,B](l: List[A], z: B)(f: (B, A) => B): B = {
    l match {
      case Nil => z
      case Cons(head, tail) => foldLeft(tail, f(z, head))(f)
    }
}


```







###  Chapter 2 

####  递归和迭代

```scala
def factorial(n: Int): Int = {
  @annotation.tailrec
  def go(n: Int, acc: Int): Int =
    if (n <= 0) acc
    else go(n-1, n*acc)
  go(n, 1)
}
```
#### Partial application

对于多个入参的函数，通过部分apply， 返回一个新函数，提供某几个参数的默认值，减少输入参数

```scala
def partial1[A,B,C](a: A, f: (A,B) => C): B => C =  (b: B) => f(a, b)
// (A, B) => C  变成了 B => C
```

#### Curry

将受多个参数的函数变换成接受一个单一参数(最初函数的第一个参数)的函数，并且返回**接受余下的参数且返回结果**的**新函数**的技术

```scala
def curry[A,B,C](f: (A, B) => C): A => (B => C) =
    a => b => f(a, b)
// （A, B） => C 变成了  A => ( B => C)  
```

以curry为例，写的更详细一些，可以写成

```scala
def curry[A,B,C](f: (A, B) => C): A => (B => C) = 
    (a : A) => {
      val innerCurry2 = (b: B) => f(a, b)
      innerCurry2
    }
    
def curry[A,B,C](f: (A, B) => C): A => (B => C) =
    a => {
    def innerCurry(b : B) : C = f(a, b)
    innerCurry
   }
```

那么，这两种有区别么？ 函数和方法的区别在哪？

#### Uncurry

```scala
def uncurry[A,B,C](f: A => B => C): (A, B) => C = (a, b) => f(a)(b)
```

#### Compose

```scala
def compose[A,B,C](f: B => C, g: A => B): A => C = a => f(g(a))
```



