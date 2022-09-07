---
layout: editorial
---

# Case 3

\[TOC]

**Case3. 读取过多无用数据，且进行了无用的repartition**

代码中我们经常用repartition去进行数据打散，防止数据倾斜。但是前提**一定是出现了严重的数据倾斜**

**现象**

线上有一段代码如下：

```scala
val df1 = sess.read.option("header", "true").option("delimiter", "|")
  .csv(impressPath)
  .repartition(4000)

println(s"${LogInfo.getLineInfo()}\tgetDF\t${df1.schema.mkString(",")}")

val df = df1.select("tid", "pvid", "mid", "time_stamp", "uid", "pid", "current_url",    "country", "gender",
  "app_version", "price", "from_page")
  .withColumn("imp", default1())
  .withColumn("pid_old", getPidOld($"current_url"))
  .drop("current_url")
  .withColumn("time_stamp1", str2timeStamp($"time_stamp"))
  .drop("time_stamp")
  .withColumnRenamed("time_stamp1", "time_stamp")
  .distinct()
  .dropDuplicates("tid", "pvid", "mid", "uid", "pid", "pid_old")
  .filter(filterFaseUidPid($"uid", $"pid", $"pid_old"))

df
```

其中比较重要的几个点在于以下几个操作，这3个操作均会触发shuffle

1. .repartition(4000)
2. distinct()
3. dropDuplicated("t\_id", "pvid", "mid", "uid", "pid", "pid\_old")

这一段对应的SparkUI DAG图如下：

![case3\_dag1](https://raw.githubusercontent.com/fuqiliang/review/master/big-data/spark/Spark%E4%BB%BB%E5%8A%A1%E4%BC%98%E5%8C%96/pic/case3\_dag1.png)

![case3\_dag\_time1](https://raw.githubusercontent.com/fuqiliang/review/master/big-data/spark/Spark%E4%BB%BB%E5%8A%A1%E4%BC%98%E5%8C%96/pic/case3\_dag\_time1.png)

我们对照代码来看，每个stage的耗时，

* Stage36: 输入数据，直接repartition(4000),输出1235.2G的数据，耗时30min
* Stage37: 输入1235.2G的数据，执行distinct(), 数据按照（"trace\_id", "pvid", "mid", "time\_stamp", "uid", "pid", "current\_url", "country", "gender","app\_version", "price", "from\_page"）进行重分布，剩余的取出的列为（"trace\_id", "pvid", "mid", "time\_stamp", "uid", "pid", "current\_url", "country", "gender","app\_version", "price", "from\_page"），取出数据931.6G,耗时11min
* Stage38:输入931.6G的数据,执行dropDuplicated("trace\_id", "pvid", "mid", "uid", "pid", "pid\_old").数据按照（"trace\_id", "pvid", "mid", "uid", "pid", "pid\_old") 进行重分布，剩余的取出的列为依旧为（"trace\_id", "pvid", "mid", "time\_stamp", "uid", "pid", "current\_url", "country", "gender","app\_version", "price", "from\_page"）,输出数据729.1G

**问题**

这段代码有几个问题：

1.  30 min的repartition是否有必要？ 之前说过repartition的意义在于取出数据倾斜，那么可以从Stage 36的输入/输出对比下是否存在数据倾斜 执行时长跨度为3s-30s，输入数据差距15M-97M,这种程度的倾斜用30min来进行重分布，实在是性价比太低。而且97M的最大数据，对后面的复杂计算能有多大影响？再之，这条SQL之后，本身就有各种数据充分，这一步repartition可以考虑省略。 

    ![case3\_input](https://raw.githubusercontent.com/fuqiliang/review/master/big-data/spark/Spark%E4%BB%BB%E5%8A%A1%E4%BC%98%E5%8C%96/pic/case3\_input.png)
2. 先按照（"t\_id", "pvid", "mid", "time\_stamp", "uid", "pid", "current\_url", "country", "gender","app\_version", "price", "from\_page"）进行了一次去重复，之后再按照("t\_id", "pvid", "mid", "uid", "pid", "pid\_old")进行去重。 

第一次的去重在逻辑上看来没有意义，这一步可以省略

1. 查看后续代码，实际业务用的列只有("pid","pid\_old","time\_stamp"）那么，select 出来的 "country", "gender","app\_version", "price", "from\_page"均是无用列，徒增中间交换数据量，可以将列精简到真正需要用到的列。
2. filter操作放在了所有操作的最后，理由跟3一样，在数据流动中，尽量将filter下推到源端，减少中间数据量

**改进**

按照这个思路下来，我们将代码改为:

```
val df1 = sess.read.option("header", "true").option("delimiter", "|")
      .csv(impressPath)
//      .repartition(4000)
 
println(s"${LogInfo.getLineInfo()}\tgetImpressDF\t${df1.schema.mkString(",")}")
 
 
val df = df1.select("t_id", "pvid", "mid", "time_stamp", "uid", "pid", "current_url")
      .withColumn("imp", default1())
      .withColumn("pid_old", getPidOld($"current_url"))
      .filter(filterFaseUidPid($"uid", $"pid", $"pid_old"))
      .drop("current_url")
      .withColumn("time_stamp1", str2timeStamp($"time_stamp"))
      .drop("time_stamp")
      .withColumnRenamed("time_stamp1", "time_stamp")
      //      .withColumnRenamed("time_stamp", "time_stamp_imp")
      .dropDuplicates("t_id", "pvid", "mid", "uid", "pid", "pid_old")
df
```

新代码上了之后，这一段对应执行情况

![case3\_dag2](https://raw.githubusercontent.com/fuqiliang/review/master/big-data/spark/Spark%E4%BB%BB%E5%8A%A1%E4%BC%98%E5%8C%96/pic/case3\_dag2.png)

两个stage完成了最后16.4G的输出，耗时10min+
