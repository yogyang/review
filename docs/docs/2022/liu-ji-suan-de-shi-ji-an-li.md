# 流计算的实际案例

问题：

在Spark structure streaming中，以下算子分别会出现什么结果。

1. groupby(x, window(time, windowlen, slide)).count + update
2. groupby(x, window(time, windowlen, slide)) + update + watermark
3. groupby(x, window(time, windowlen, slide)) + append + watermark
4. groupby(x, window(time, windowlen, slide)) + append + watermark + lag

要回答这个问题，我们需要先回顾一下Spark structure streaming的基本逻辑，简单可以概括为

1. Spark按照trigger,进行每次addBatch操作，来出发一次计算
2. 进行结果计算，如果有涉及到state的计算，那么必然会涉及到计算中间值和完成计算两个概念
3. 按照不同的输出模式，来处理计算结果

假定window len=10mins, slide=5mins,

那么给定一个x, 他要计算的是window是

```scala
w1 (10:00 - 10:10） 
w2 (10:05 - 10:15)
w3 (10:10 - 10:20)
w4 (10:15 - 10:25)
....
```

数据到达如下,因为spark structure streaming里是靠trigger来dump数据，trigger\_time = arrive\_time

```scala
trigger_time.    batch   time.     x
10:02             0      10:01     1
10:02             0      10:02     2
10:07             1      10:01     1  
10:12             2      10:09     1 
```

*   case 1. groupBy(x, window(time, len, slide)).count + update

    模式是update: 意味着每次trigger完之后，计算结果有改动的就会输出。

    那么从10:00以后的每个trigger, 即每次计算完成后，如果当前有数据变化的window,那么就会一直有输出结果。

    那么这三个batch的输出会分别是

    ```scala
    batch   x   window.           count 
    0       1   (10:00 - 10:10)    1
    0.      2   (10:00 - 10:10)    1
    1       1   (10:00 - 10:10)    2
    2.      1   (10:00 - 10:10)    3
    2.      1.  (10:05 - 10:15)    1
    ```

    如果这个sink直接是到table,那么你会发现，你的table里有非常的中间计算值，等于每次trigger的计算值的变化都会被记录到table中。

    真实的notebook测试结果，可以对比一下，其中write\_time可以类比batch id

    思考一下这个模式，会发现，因为update模式输出的是**变化的row result的**当前最新结果\*\*\*\*,那么久导致Spark内存中，必须保留上一次的计算结果，才能完成一个

    ```scala
    当前结果 = agg(上一次state结果 + 这一次的输入计算结果)
    ```

    试想这种设定下

    *   流数据是源源不断进入的，那么Spark如何回答**某个window的计算结果不会被更新了呢**？

        答案是无法保证。

    因此，这个使用模式其实非常危险，因为你无法知道后续那个window的结果会被更新，所以也可以说，每个window的计算都没有停止，所以Spark需要永远保存所有window当前的计算结果，且永远无法释放，这个streaming一直跑下去，肯定会OOM，不管你如何管理你的中间state.
*   case 2. groupBy(x, window(time, len, slide)).count + update + watermark

    那继续来考虑case1, 我们说到case1下，Spark无法进行释放state, 核心原因在于

    **无法确定某个window的数据结果不会再被更新**

    那么解决它就好，这个问题的根源又是流计算的一个老问题了：

    流的数据在源源不断的输入的，所以如果不加任何数据有效性的限定，那么计算永远不可能停止。

    因此流计算里有watermark来解决这个问题，用watermark就可以回答一个问题，在Spark中

    💡 watermark=max(每个batch当前watermarkCol的最小值-timeinterval, lastWatermark)(未认证)

    如果数据的watermarkCol<当前watermark的话，换言之，数据的lag超过了一定间隔，那么可以认为他是个无效数据，无效数据是不需要加入我们的计算中的。

    watermark + timestamp 得 window ，就变相得告诉计算引擎：超过某个时间点之后，不会再有新的数据进去这个window的计算了，也就告诉了Spark，什么时候可以清理掉某些window的结果了。

    具体举例：watermark设置为watermark(time, 5mins)，那么这个模式下的输出应该是

    ```scala
    batch   x   window.           count  trigger_time
    0       1   (10:00 - 10:10)    1.     10:02
    0.      2   (10:00 - 10:10)    1.     10:02
    2.      1   (10:00 - 10:10)    2.     10:12 
    2.      1.  (10:05 - 10:15)    1.     10:12
    ```

    区别在于

    1. batch 1 的数据犹豫lag过大，数据无用
    2. 实际上对于(10:00 - 10:10) 这个window, 可以理解在10:15之后，这个数据不会再变化，页不会再出现在output中
*   case 3. groupby(x, window(time, windowlen, slide)).count + append + watermark

    这个模式下需要回一下append:

    > This is the default mode, where only the new rows added to the Result Table since the last trigger will be outputted to the sink. This is supported for only those queries where rows added to the Result Table is never going to change.

    简单总结就是，只有数据计算完成了，才会把结果输出到sink.

    所以这个模式下，watermark是必须的，理由跟case 2相同。

    那么这个跟Case 2会有什么不同呢？

    * 只输出最终结果
    * 输出的时机是确定计算已经结束

    比如对于w1(10:00 - 10:10) 这个window， watermark interval设置为5mins 的时候，那么当watermark的值推进到 > 10:10 之后， 这个window就不可能再有数据进入，那么这个window的数据结果就可以输出了。

    假设数据都是实时到的，那么processTime=10:15的时候，数据的time=10:15到了，那么理论上就可以看到10:15之后第一个trigger的batch将输出w1的数据，依次类推其他的window.

    在实际的notebook上，我们看一下结果。

    ```
      首先一个显著的区别是，输出列明显比output少很多，因为都是最终结果。

       第二个问题是，write_time比window.end要多10mins,  而我们的trigger. interval 才4mins, 理论上极限情况(8:00-8:30) 这个window顶多也就在 8:30+watermark interval的时候输出(上图中watermark interval设置为 2 minutes), 原因是什么呢？

       这就是实际中，我们最常碰到的case 4.
    ```
*   case 4. groupby(x, window(time, windowlen, slide)).count + append + watermark + lag

    case 3 中我们提到了我们需要确定 **计算结束的时机， 这个时机应该是 watermark 推进到window.end.**

    这里有一个关键点就是watermark的计算， 首先我们看看我们的watermark是怎么定义的

    ```
         可以看到，我们定义的watermark是EventTime的watermark,  计算的值是数据里的col(”timestamp”), 那如果我们的流数据整个有lag, 

           timestamp=10:10 的数据 要到。processTime=10:20的时候到来，
    ```

    那么整个watermark都会延后了10分钟，自然，流计算的结果也就被推后了10分钟。这就是我们在实际的notebook测试中看到的问题的原因了。

**Reference**

[Spark 中间State在不同输出模式下的处理](https://github.com/apache/spark/blob/master/sql/core/src/main/scala/org/apache/spark/sql/execution/streaming/statefulOperators.scala#L383)

[https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html#handling-late-data-and-watermarking](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html#handling-late-data-and-watermarking)

[Flink的输出模式](http://www.whitewood.me/2020/02/26/Flink-Table-%E7%9A%84%E4%B8%89%E7%A7%8D-Sink-%E6%A8%A1%E5%BC%8F/)

[Flink sink 模式的实际例子](https://wiki.zhangzuofeng.cn/bigdata/Flink/Flink-sink-mode/)
