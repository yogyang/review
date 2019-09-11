[TOC]

## BOOK
https://learning.oreilly.com/library/view/functional-programming-in/9781617290657/kindle_split_014.html

### Chapter 6


以随机数生成为例，传统的Java的random方法里，每次调用会改变内部Random seed的值，使得方法不具备refrence transparent.

可以通过，把变化的seed作为传参的方式将random改写。
```
Don’t update the state as a side effect, but simply return the new state along with the value that we’re generating.
```

()[]



### Chapter 5

简单的两次函数调用触发两次print

```
scala> def maybeTwice(b: Boolean, i: => Int) = if (b) i+i else 0
maybeTwice: (b: Boolean, i: => Int)Int

scala> val x = maybeTwice(true, { println("hi"); 1+41 })
hi
hi
x: Int = 84
```
通过lazy引入thunk, 将j 变成惰性求值，延后并cache计算结果
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



### Chapter 4

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

###  Chapter 2
递归和迭代

```
def factorial(n: Int): Int = {
  @annotation.tailrec
  def go(n: Int, acc: Int): Int =
    if (n <= 0) acc
    else go(n-1, n*acc)
  go(n, 1)
}
```