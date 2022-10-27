# 从delta + optimize + gen\_manifest的bug聊起(2)

从第一段的总结后，基本确定databricks商业版

Optimize的基本逻辑是

1. 以一定策略将需要合并的文件进行group,每个group放在一个batch里， 这里需要注意的是，**同一个partition里多个文件也可能被拆分到不同的batch里。**
2. 每个batch都是一个单独的ranscation并行执行。

GenManifest的逻辑是：

&#x20;1.将当前版本的所有parquet files写入到manifest文件中。

GenManifest的逻辑基本跟[开源版](https://github.com/delta-io/delta/blob/master/core/src/main/scala/org/apache/spark/sql/delta/hooks/GenerateSymlinkManifest.scala)符合。

但是Optimize的逻辑却跟开源版对不上。

{% embed url="https://github.com/delta-io/delta/blob/4a401ea992fe105de61cb152a8082b86b85551dd/core/src/main/scala/org/apache/spark/sql/delta/commands/OptimizeTableCommand.scala#L178-L187" %}

#### 开源版本

开源版本delta 2.0.0版本Optimize的行为是

对于\`optimize db.tb where {predicate}\`， 排除zorder的情况下

1. filter出predicate涉及的所有小文件，这里小文件的定义是，fileSize < \`optimize.minFileSize\`, 默认就是1G
2. 将需要合并的文件，按照partition分组，每个partition内部又按照\`optimize.maxFileSize\`将文件group在一起，成为jobs = Seq\[Map\[String, String], Seq\[AddFiles]]。 这里其实还是要注意同一个partition下如果小文件过多，也有可能出现一个partiiton下的比如10个文件，被切成2分，即Seq({date=2022-10-24 -> Seq\[AddFile1, AddFile2]}, {date=2022-10-24 -> Seq\[AddFile3]})
3. 将2中group出来的partition -> files, 提交到本地的线程池总进行并发地合并，并发度由\`optimize.maxThreads\`来控制。
4. 所有job完成后，**统一进行一个commit提交**。

对于上述流程，我们可以简单进行一个测试

环境： Spark 3.3, delta-core 2.1.0

```scala
val data = spark.read.format("parquet")
  .load("part-00000-0d661a48-e0bb-44f9-9209-21c1ede8d8f5.c000.snappy.parquet")
data.cache()
println(data.count())

import spark.implicits._
val bigDf = (0 to 3).foldLeft(data)((df, i) => df.union(df))
bigDf.withColumn("pk", $"device_hash_num" % 10)
  .write
  .partitionBy("pk")
  .format("delta").saveAsTable("default.bigTest")

val deltaTable = DeltaTable.forPath("spark-warehouse/bigtest")
deltaTable.optimize().executeCompaction()
```

本地运行，可以看到，optimize阶段：

![](<../../.gitbook/assets/image (8).png>)

由于我的数据问题，其实只有一个分区pk=0, 也可以看到，optimize时候，pk=0下的总共32个小文件被分成两个job， 被线程池并发提交，执行coalesce(1)，最后optimize之后，其实就变成了2个文件。

这里又有一个有意思的小点，可以发现每个合并文件子任务里，只用了 一个task进行合并，所以社区的人又提交了一个配置

<pre><code><strong>optimize.repartition.enabled</strong></code></pre>

希望进一步提高合并效率：

{% embed url="https://github.com/delta-io/delta/blob/master/core/src/main/scala/org/apache/spark/sql/delta/commands/OptimizeTableCommand.scala#L310-L315" %}

 查看history,可以看到，这个optimize虽然分了两个job, 但是还是是一次提交。

```

+-------+-----------------------+------+--------+----------------------+---------------------------------------------------------------------------------+----+--------+---------+-----------+-----------------+-------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+------------+-----------------------------------+
|version|timestamp              |userId|userName|operation             |operationParameters                                                              |job |notebook|clusterId|readVersion|isolationLevel   |isBlindAppend|operationMetrics                                                                                                                                                                                                                            |userMetadata|engineInfo                         |
+-------+-----------------------+------+--------+----------------------+---------------------------------------------------------------------------------+----+--------+---------+-----------+-----------------+-------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+------------+-----------------------------------+
|1      |2022-10-27 22:30:01.403|null  |null    |OPTIMIZE              |{predicate -> [], zOrderBy -> []}                                                |null|null    |null     |0          |SnapshotIsolation|false        |{numRemovedFiles -> 32, numRemovedBytes -> 1373320330, p25FileSize -> 308128260, minFileSize -> 308128260, p75FileSize -> 1032248261, p50FileSize -> 1032248261, numAddedBytes -> 1340376521, numAddedFiles -> 2, maxFileSize -> 1032248261}|null        |Apache-Spark/3.3.0 Delta-Lake/2.1.0|
|0      |2022-10-27 22:20:29.343|null  |null    |CREATE TABLE AS SELECT|{isManaged -> true, description -> null, partitionBy -> ["pk"], properties -> {}}|null|null    |null     |null       |Serializable     |true         |{numFiles -> 32, numOutputRows -> 1593632, numOutputBytes -> 1373320330}                                                                                                                                                                    |null        |Apache-Spark/3.3.0 Delta-Lake/2.1.0|
+-------+-----------------------+------+--------+----------------------+---------------------------------------------------------------------------------+----+--------+---------+-----------+-----------------+-------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+------------+-----------------------------------+
```

#### 商业版

所以问题是，从开源版本的实现来看，我感觉不可能出现一个optimize命令造成多次transanction的提交。

所以，同样逻辑的代码在databricks DBC11.3上跑了一遍

<img src="../../.gitbook/assets/image (6).png" alt="" data-size="original">

<img src="../../.gitbook/assets/image (7).png" alt="" data-size="original">

从history来看，会发现

1. 商业版的Optimize指标上都多个了\`batchId:0\`, 而执行的job description也会变成
2. Batch x Compactingxxx , 而且也不是默认的1 task执行合并了。

而在我的测试中，应该file size并没有达到他进行batch拆分的标准，不过从optimize commit里有batchId来看，商业版的行为还是拆分出来的batch是一个commit.

也就是目前线上在单次optimize数据量特别大的时候，出现的情况。



#### 总结

这个问题记录下来，总结一下，又一个感慨。

就是购买商业服务省去了许多运维成本，同时他与开源的不统一，其实让我们开发使用者在排查问题时，还是需要依赖于商业支持。

有些问题，就不是你自己能够coding搞定了。
