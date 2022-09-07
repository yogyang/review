---
description: Spark流处理，相对于批处理，简单理解来说，就是流处理的数据是一直在增长的。
---

# Streaming 101

## Spark Streaming

Spark Streaming将每一段间隔的数据切割成RDD，那么源源不断的流式数据就是连续不断的RDD序列，这样的序列称为DStream. DStream是基于RDD上的API。

在定义DStream时，需要定义数据分割的间隔，这个间隔就决定了此次流式处理的最小的延迟。

当数据被分割成一段一段小数据时，可通过window来进行某段时间内的数据统计，如例子中

> 1. 数据按照1秒进行分割
> 2. 使用window可以进行比如 （1- 60 秒的数据统计，5- 65 秒的数据统计， 10- 70 秒的数据统计）， 那个统计的滑动窗口即，窗口长度=60s，滑动间隔= 5s.

摘自https://time.geekbang.org/column/article/96792 !\[屏幕快照 2019-09-15 下午12.21.43]\(/Users/yoga/Desktop/屏幕快照 2019-09-15 下午12.21.43.png)

```
sc = SparkContext(master, appName)
ssc = StreamingContext(sc, 1) // 1秒的时间间隔决定了数据是如何切割的，也决定了这个流式处理的lantency
lines = sc.socketTextStream("localhost", 9999)
words = lines.flatMap(lambda line: line.split(" "))
```

!\[屏幕快照 2019-09-15 下午12.25.57]\(/Users/yoga/Desktop/屏幕快照 2019-09-15 下午12.25.57.png)

## Structured Streaming

提供了两种模式micro-batch, continuous mode

micro-batch还是之前的微批处理思想，跟DStream的区别我理解下来最基本的就是

> 封装了基于DataSet/DataFrame的API，用上了Spark SQL 内置的查询优化。
>
> 使用方式上有了很大的区别，一定要构建一个streamingQuery来启动streaming查询（不确定Dstream的使用）

至于关于process time & event time的问题，我觉得只是Dstreaming是基于RDD的操作，没有数据schema信息，那么必然在DStreaming这种API上，默认接口上只能提供到process time的windows操作。

而Structured Streaming在处理数据时候，若数据本身带有timestamp ， 那么在解析完数据schema后，event time也就是某一列，按照SQL的处理方式即可在windows上使用该timestamp列进行操作。

**Sample Code**

```scala
val cols = List("user_id", "time", "event")

    import sparkSession.implicits._

    //构建DStreaming，从kafka中读取数据
    val streamDF = sparkSession.readStream
      .format("kafka")
      .option("subscribe", "test.1")
      .option("kafka.bootstrap.servers", "localhost:9092")
      .option("startingOffsets", "earliest")
      .load()
    streamDF.printSchema()
    // 直接从kafka中读取出来的结构如下
    // root
    // |-- key: binary (nullable = true) ？？
    // |-- value: binary (nullable = true) 消息的二进制
    // |-- topic: string (nullable = true) topic
    // |-- partition: integer (nullable = true) 该消息所属partition
    // |-- offset: long (nullable = true) offset
    // |-- timestamp: timestamp (nullable = true) producer产生消息的时间/broker写入消息的时间
    // |-- timestampType: integer (nullable = true)

   //取出消息的value, topic, partition组成
    val lines = streamDF
      .selectExpr("CAST(value AS STRING)",
                  "CAST(topic as STRING)",
                  "CAST(partition as INTEGER)")
      .as[(String, String, Integer)]

    val df =
      lines.map {
        line =>
        val columns = line._1.split(";") // value being sent out as a comma separated value "userid_1;2015-05-01T00:00:00;some_value"
        (columns(0), Commons.getTimeStamp(columns(1)), columns(2))
      }.toDF(cols: _*)

    df.printSchema()
   // root
   // |-- user_id: string (nullable = true)
   // |-- time: timestamp (nullable = true)
   // |-- event: string (nullable = true)

    import org.apache.spark.sql.functions._
    val countDF = df.groupBy(
      window($"time", "2 minutes", "1 minutes"),
      $"user_id"
    ).count()
    countDF.printSchema()


    val viewDF = countDF
      .select($"window.start", $"user_id", $"count").sort($"user_id")
    // root
    // |-- window: struct (nullable = true)
    // |    |-- start: timestamp (nullable = true)
    // |    |-- end: timestamp (nullable = true)
    // |-- user_id: string (nullable = true)
    // |-- count: long (nullable = false)

   // 定义 sink，输出到console,输出模式是complete
    val consoleOutput = viewDF.writeStream
      .queryName("testStreaming")
      .outputMode("complete")
      .format("console")
      .start()

    consoleOutput.awaitTermination()

-------------------------------------------
Batch: 0
-------------------------------------------
+-------------------+----------+-----+
|              start|   user_id|count|
+-------------------+----------+-----+
|2015-05-01 00:10:00| user_id:1|    6|
|2015-05-01 00:11:00| user_id:1|    6|
|2015-05-01 01:20:00| user_id:1|    1|
|2015-05-01 01:21:00| user_id:1|    1|
|2015-05-01 01:29:00|user_id:10|    1|
|2015-05-01 00:19:00|user_id:10|    1|
|2015-05-01 01:30:00|user_id:10|    1|
|2015-05-01 00:20:00|user_id:10|    1|
|2015-05-01 00:21:00|user_id:11|    1|
|2015-05-01 01:30:00|user_id:11|    1|
|2015-05-01 01:31:00|user_id:11|    1|
|2015-05-01 00:20:00|user_id:11|    1|
|2015-05-01 01:32:00|user_id:12|    1|
|2015-05-01 00:22:00|user_id:12|    1|
|2015-05-01 00:21:00|user_id:12|    1|
|2015-05-01 01:31:00|user_id:12|    1|
|2015-05-01 00:23:00|user_id:13|    1|
|2015-05-01 00:22:00|user_id:13|    1|
|2015-05-01 01:33:00|user_id:13|    1|
|2015-05-01 01:32:00|user_id:13|    1|
+-------------------+----------+-----+
only showing top 20 rows
```

以上code就是一个简单的示例，从kafka中读取消息，按照windows(2minutes, 1 minutes)统计user\_id出现的次数

### **Micro-batch Mode & Continuous Processing Mode**

https://databricks.com/blog/2018/03/20/low-latency-continuous-processing-mode-in-structured-streaming-in-apache-spark-2-3-0.html

通过设置trigger(continuous = "5 seconds") 来切换

从上面那边文章看来， micro-batch 的运行原理：

> 1. 定时批量拿数据，拿到数据之后这批待处理的数据offset先落地 ,写入log(write ahead log)
> 2. 进行batch数据处理
> 3. 提交commit offset

这种模式其实跟直接NDC的处理mysql binlog那一套区别只在于offset落地的时机，不过本质好像差不多。这个模式下可以实现在数据源和消费满足一定前提的情况下，可以实现exactly-once

> 消息源支持数据reply, 这样可以保证在step2失败的情况下，可以重复拿失败batch的数据，即至少已经达到at-least-once 进行数据处理的时候，只要支持操作幂等，链路上就可以实现exactly-once，就是可以保证在step 3失败的情况下，数据的重复消费不会导致output的数据重复。

而在structed streaming中，数据消费以及数据处理都被spark封装完成，只要他想就可以实现到底是exactly-once还是at-least once.

### Questions

很多问题不明白

1. 在 structured streaming 流处理模式下，流input 对应的初始DF是如何定义的？ 在原来批处理模式下，一个文件我们读进来的时候就可以定义它被概括为N个partition，那么真正触发action的时候，可以分别由各个exectuor去读取一部分数据，对这一部分数据进行运行，达到分布式计算。 那么流处理 microbatch 模式下，比方说，对于一个kafka的输入流，是在每次trigger触发的时候，数据到底是怎么读取到spark execturor的呢？按照offset分成多个数据分区，再由各个executor根据offset去读数据么？kafka一个分区只能给一个consumner group.consumer 消费，这个思路应该不行吧？ 还是说按照kafka topic的parition进行默认分区？
2. streaming 和kafka的结合下，executor和consumer的映射 比如，输入源为kafka, topic = test, topic partition = 3. 那么用spark接入该kafka的时候，输入源DF就是3个partition, 一次 job -> consumer-group, 每个executor就对应着一个executor?
3. spark 流计算micro-batch模式下原理是到点进行切割成一个小batch , 计算应该是以这个batch为一个job单位，那么一次流计算对应的DF是不是对应着多个RDD？
4. DStream在structure Streaming 里是不是还是作为底层实现在使用？
5. 如果DStream里对应着多个RDD batch，那么当使用windows的时候，如果window的滑动窗口大小跨了batch，那是不是涉及到多个RDD的之间的数据聚合？这个在基于event time的处理上也是一样的， 比如1条消息event time 是在第1s产生，process time是第10s, windows(5,5)，那么这条数据到底落在哪个batch里？？？

#### Reference

[https://www.infoq.cn/article/UEOq-ezu4ImwHxGiDFc8](https://www.infoq.cn/article/UEOq-ezu4ImwHxGiDFc8)

[http://aseigneurin.github.io/](http://aseigneurin.github.io/)

[https://time.geekbang.org/column/article/97121](https://time.geekbang.org/column/article/97121)

[https://github.com/ansrivas/spark-structured-streaming](https://github.com/ansrivas/spark-structured-streaming)

[https://databricks.com/blog/2018/03/20/low-latency-continuous-processing-mode-in-structured-streaming-in-apache-spark-2-3-0.html](https://databricks.com/blog/2018/03/20/low-latency-continuous-processing-mode-in-structured-streaming-in-apache-spark-2-3-0.html)
