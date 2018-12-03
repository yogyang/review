##job need shuffle

[TOC]



由上节我们已知，spark中一个job的执行流程可简化为：

![屏幕快照 2018-10-22 下午11.10.58](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/simpleviewfromdriver.png)

对于无shuffle的job

```
step 1. stage拓扑图中只有一个ResultStage
step 3. executor 执行task之后，将结果直接发回给driver
step 4. driver在接收到所有的task的结果后，对JobWaiter进行唤醒， 在driver端对所有的result 按照result handler进行处理。
```

那么，有shuffle的job有什么不一样。
可以按照之前分析出的流程再走一遍

示例程序：

``` scala
val dataRdd = context.parallelize(data, 3)
val groupRdd = dataRdd.groupBy(r => r.getInt(0))
val count = groupRdd.count()
```

### 1. 构建stage DAG

在真正做action之前，我们通过一系列的transformation得到了一个finalRDD，本例中即groupRDD,之后我们在groupRDD上触发一个action,才真正得开始向spark提交一个job.

那么，通过RDD的dependencies，我们已知groupRDD的依赖链：
![屏幕快照 2018-10-22 下午11.11.53](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/rdd_dependency.png)

在构建finalStage的时候，DAGScheduler从finalRDD(groupRDD)往前推算，查看是否需要建partentStages, 判断原则是依赖链上遇到ShuffleDependency即生成一个ShuffleStageMap.

那么，上述RDD依赖链即对应成以下stage DAG图
![屏幕快照 2018-10-22 下午11.12.14](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/stage_cut.png)

切割重点在于
>1. getShuffleDependencies: 切割算法即通过finalRDD进行深度遍历，找到最近的父级ShuffleDependency
>  即对于如下RDD链
>  ![屏幕快照 2018-10-22 下午11.12.35](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/dag_alg.png)
>  对D1 调用 getShuffleDependencies => [B3, C2]


>2. 对1得到的shuffleDependencies构建ShuffleMapStage


### 2. ShuffleMapStage

由上述可知，对于示例程序来说，DAG拓扑图构成为ShuffleMapStage->ResultStage. DAG 拓扑图生成后，我们来到step2 - submitStage(finalStage).

submitStage的流程之前说过, 核心归结为一句话：
```
Submits stage, but first recursively submits any missing parents

先检查该stage是否有依赖的parentStage没有执行，
若有 ->  先submit 所有的parentStage, 该stage 加入waitingStage set中
若无 ->  直接submit该stage
```
本例中，由于父stage stage_1的存在，程序会先submit stage_0. 注意跟之前的submit stage最大一个区别来了。

不妨回忆一下之前无shuffle的job中，此处submit 为ResultStage, ResultStage会被拆封成ResultTask, ResultTask在各个executor上执行完后会将result发回给driver,由 driver根据resultHandler中的定义来处理result,并汇总结果，直到JobWaiter的唤醒，至此整个job完成，并在driver端返回结果。

而此处最大的不同点即是这次我们需要submit的是一个**ShuffleMapStage**.同样的，ShuffleMapStage再被提交时候，先按照submitStage的基本法走，本例中stage_0之前无parent，则直接调stage_0. Stage_0被拆分成多个**ShuffleMapTask**.

#### 2.2. ShuffleMapTask

ShuffleMapTask看类构成跟ResultTask差不多，主要区别在于runTask方法的实现。

首先理解shuffle和普通的Resultstage又什么区别， ResultStage是整个job的最后一个阶段，这个阶段是明确的需要将**结果返回给driver**的，让driver进行结果的汇总的。

而Shuffle的实质是整个计算链路的中间态，shuffle负责的是**数据的重分布**， 即如下图：

![shuffle](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/shuffle.png)

那说起shuffle，就离不开map端和reduce端, map端即对应着数据原来的分布方式，而reduce端则对应着数据重新分布后的状态，而中间这个过程就是shuffle。而整个数据重组的过程就相应得分为map端的数据划分- ShuffleWriter, 以及reduce端的数据聚合ShuffleReader.

那么对于一个shuffle任务来说，比如某个shuffle任务去处理原map端p0分区m_p0 的数据划分，那么它并不需要将重新分布后的数据重发给driver，因为首先driver并不需要重新分布的数据，它需要的只是最终的结果。重新分布后的数据比如r_p0只需要被后续的负责该分区的executor获取即可。对于driver,他需要知道的只是shuffle完成后，reduce端 p0的数据分布在哪些机器上，它只需要能够告知下一个stage执行任务的executor去哪里获取自己负责的数据就够了。

基于这个思想，ShuffleMapTask与ResultTask一个最大的区别就呼之欲出了，返回结果的不同。ShuffleMapTask返回的结果永远是MapOutput,而ResultTask需要返回的是fun指定的输出。

| ResultTask.runTask     | func(context, rdd.iterator(partition, context))              | 对对应的partition数据进行 定义的func 调用 |
| ---------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| ShuffleMapTask.runTask | writer=manager.getWrite(dep.shuffleHandle, partitionId, context); writer.write(rdd.iterator(partition, context)) | 根据**shuffleDependency**生成ShuffleWriter,对对应的parition进行shuffle write |
从上述执行可以看出，ResultTask的核心在与func, ShuffleMapTask的核心在于dep.shuffleHandle，这两者都直接决定了后续task的执行逻辑。而这两者都是通过之前taskBinary里反序列化解析得到的。

再细看一下ShuffleMapTask
![ShuffleMapTaskCode](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/shuffleMapTask.jpg)

**重点**

```
1. MapStatus: 返回值，Includes the block manager address that the task ran on as well as the sizes of outputs for each reducer, for passing on to the reduce tasks.
2. ShuffleWriter， 数据如何重新分布的逻辑
3. ShuffleDependency
```

回顾下Task的构建过程里, taskBinary里ResultTask包含的就是(Rdd, func ),  而ShuffleMapTask对应则是（Rdd, shuffleDep. 可以说，Shuffle.shuffleDep描述了该shuffle该如何执行的所有核心逻辑。

```scala
// For ShuffleMapTask, serialize and broadcast (rdd, shuffleDep).
// For ResultTask, serialize and broadcast (rdd, func).
val taskBinaryBytes: Array[Byte] = stage match {
    case stage: ShuffleMapStage =>
         JavaUtils.bufferToArray(
            closureSerializer.serialize((stage.rdd, stage.shuffleDep): AnyRef))
    case stage: ResultStage =>
          JavaUtils.bufferToArray(closureSerializer.serialize((stage.rdd, stage.func): AnyRef))
      }
```

#### 2.3 ShuffleDependency

Shuffle.shuffleDep实现类为ShuffleDependency，这一节我们来看看这个类。

首先一个问题，这个stage.shuffleDep是什么时候生成的？

回到RDD的依赖链，DAG拓扑图就是根据依赖链里的ShuffleDependency进行切割的。所以ShuffleDependency和ShuffleRDD是1对1 的，这是一个ShuffleRDD的固有属性值，每个ShuffleRDD生成的时候，其对应的ShuffleDependency该如何就已经确定了。

```scala
override def getDependencies: Seq[Dependency[_]] = {
    val serializer = userSpecifiedSerializer.getOrElse {
      val serializerManager = SparkEnv.get.serializerManager
      if (mapSideCombine) {
        serializerManager.getSerializer(implicitly[ClassTag[K]], implicitly[ClassTag[C]])
      } else {
        serializerManager.getSerializer(implicitly[ClassTag[K]], implicitly[ClassTag[V]])
      }
    }
    List(new ShuffleDependency(prev, part, serializer, keyOrdering, aggregator, mapSideCombine))
  }
```

回到ShuffleDependency , 它是如何定义了Shuffle该如何执行的？

```scala
val shuffleHandle: ShuffleHandle = _rdd.context.env.shuffleManager.registerShuffle(
    shuffleId, _rdd.partitions.length, this)
```

ShuffleDependency除去从父类中继承的成员变量外，还有一个shuffleHandle,根据当前dependency的一些基本属性以及配置生成不同的ShuffleHandle, ShuffleHandle有以下三种

> 1.  BypassMergeSortShuffleHandle
>
> 2. SerializedShuffleHandle
> 3. BaseShuffleHandle

而在执行ShuffleMapTask时的核心shuffleWriter正是根据不同的handler生成的。

#### 2.4 ShuffleWriter

shuffleWriter是干什么的？

![shuffleWriter](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/shuffle_writer_general.png)

如上图，shuffleWriter的作用就是将当前map端分区的数据，按照新的分区规则，进行数据划分。注意在Spark2.0+以后，shuffleWriter执行完成后的状态永远是 **一个dataFile(包含从map_pi分区按照新规则划分出来的所有数据，并按照reduce端的partition顺序进行排列) + 一个索引文件(指示上述dataFile中 reduce 分区的索引， 如0-10M 为reduce_p0, 10-20M 为reduce_p1)**.

在Spark 2.0+ 以后，Spark提供了三种shuffleWriter, BypassMergeSortShuffleWriter,UnsafeShuffleWriter,SortShuffleWriter.分别对应这上述三种handler. 

![dependency2writer](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/shuffledependency2writer.png)

而整个逻辑下推，可以得到如下shufflewriter的生成策略：

![writerlogic](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/shufflewriter_dispatch.png)
下面对应每个wirter我们来分别描述。



#####  BypassMergeSortShuffleWriter
该writer的策略为
![bypassmergeSortShuffleWriter](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/bypassmerge.png)

代码上也可以看到writer的核心结果产生逻辑， 一个dataFile以及对应的索引文件

![bypassmergecode](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/bypassmergeShufflerWriter.png)

##### SortShuffleWriter

简单来说策略如下：

概括起来就是，记录

1. 先逐条地读如内存的buffer中
2. 采取外部排序的思想，将buffer中的数据通过sort and  spill写入磁盘，形成一个一个局部有序的文件
3. 对所有局部有序的文件进行merge,用堆排序的方式每个小文件读一点进行排序，最后输出为一个整体有序的大文件，排序顺序为reduce_partition_id, 用户自定义order
4. 生成对应的index文件。

![drawing](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/unsafeShuffle.png)

然后，其实这是一个非常负责的writer,首先特性：

1. 支持aggeration,

2. 支持sort, sort by 首先是reduce_partitionId, 其次 支持指定 key。

我觉得理解SortShuffleWriter根据它的特性抓住两点

1. 内存的buffer是个hashtable结构，为什么？ 因为hash找东西最快。那么为什么需要很快得找到东西，因为需要支持聚合。

   想象下聚合是什么意思，即使对应同样的key, 依照聚合函数的定义把value聚合在一起。

   那么去理解这个hashtable的如下设计也就不太困难了。

   ![drawing](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/hashtable.png)

   用hash table，可以方便得找到某个指定K值，若已经存在则将其的V值进行聚合后更新V值。

   而此处的K值默认下 reduce_partitionId, 若用户指定了order key，则变成（reduce_partionId, order_key）

2. 由于buffer内用的是hash table，hashtable里是无序的，那我们怎么保证顺序呢？

   这个时候就用到了外部排序的思想，每当buffer写满，内存不够再分配新的buffer出来，那么就将当前buffer里的这些数据按照K值进行排序，之后写入磁盘，形成一个一个的局部有序的文件，这个过程就是sort and spill.

   而当所有的记录都被spill成多个局部有序的文件后，再通过堆排序将这些局部有序的文件整体进行排序，这些过程封装之后，呈现给程序的就是一个Iterator. 每当调用iterator.next()时候，得到的是下一个按照K值排序好的下一个值，那么由于K值第一排序位永远是reduce_partitionId, 所以当某次iterator.next()拿出来的数据是reduce_p1的值，也就意味着reduce_p0的数据已经拿完了，这个时候，我们可以记录下来当前写了XXXbytes了，也就是0-XXX 为  reduce_p0。同理，或许XXX-YYYY为reduce_p1, YYY-ZZZ 为reduce_p2.

   那么整个过程下来，最终又回到shuffle writer的输出：一个data_File +   一个索引文件。

整个SortShuffleWriter的详细过程，可以参见 https://www.cnblogs.com/itboys/p/9201750.html



##### UnSafeShuffleWriter

该shuffle 策略为：

![unsafe](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/sortshuffle.png)

1. 读取文件记录，按照新的partitioner生成数据，放入内存中。这里要注意，数据已经被序列化了，这里写入内存page直接是序列化好的字节流。

2. 每次在内存page里读入记录时候，在一个inmemory sorter里记录下这条记录对应的（reduce_partitonId, 内存page里对应的地址）

3. 当内存不够或者记录数超过设定阀值时，通过inmemory sorter里按照reduce_partitonId 进行排序，按照排序后的顺序，依次将对应地址的字节流直接拷贝到spill文件中。由于spill生成的文件已经是按照partitionId排好序的，那么对于这个spill文件也会有个对应的SpillInfo信息，记录着该spill文件中0-XX为reduce_p0，XX-YY为reduce_p1...

4. 对spill文件进行合并，这次操作很简单，将spill1 spill2 spill3中的 reduce_p0数据直接拷贝至data_file,之后在spill1 spill2 spill3中reduce_p1的全部拷贝，依次类推，最后可以得到一个整合的dataFile+索引文件。

更详细的也可以参见 https://www.cnblogs.com/itboys/p/9201750.html。



 ### 3.Map -> Reduce

当ShuffleMapTask执行完成后，执行子任务的executor将结果（dataFile + indexFile）总结成MapOutput发给driver. 而MapOutput里主要带着两个信息：

  a.  对于shuffleId=I的任务，当前executor上该shuffle的reduce1, reduce n的数据，

  b.  每个数据块大小

当所有的ShuffleMapTask完成后，driver收到了所有的MapOutput结果，即知道了shuffle map完成后，新生成的reduce端数据的分布情况。

![map](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/mapoutput2driver.png)

即当前的这个ShuffleMapStage完成，开始下一个stage的执行。整个shuffle过程也要从map端转到reduce端了。

ShuffleMapStage之后的stage,最后一定会执行到ShuffleRdd.computer,也就是 reduce端要进行shufflerReader.read()， 完成重分布后数据的读取。

 ![map2reduce](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/nextstagshuffleRdd.compute.png)

 ### 4. ShuffleReader

#### 4.1 ShuffleBlockFetcherIterator

 在Spark2+以后，shuffleReader默认实现为BlockStoreShuffleReader.Spark在编程接口上reduce端的数据读取抽象成了Iterator(ShuffleBlockFetcherIterator)，每次读取next()时候，即进行吓一跳数据的读取。

read具体数据读取的流程为：

![reader](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/reader_Logic.png)

即

1. 按照executor的地址，划分当前map过后，reduce端partition数据的分散情况

2. 按照executor的地址，划分出哪些数据块需要走网络，从别的executor上获取，哪些数据块可以直接本地读取

3. 将Request打散并异步获取对应的数据块的输入流(InputStream)，放入results中

4. 每次调用next()时候，其实就是在调用某个数据块输入流的数据

结合一个实际的例子来说：

比如，当前在executor2上执行 ShuffleRdd p0 - task.那么对应上面的步骤

1. 首先通过询问driver，获取当前的shuffleRdd在map完成后，partition 0 的数据散落分布情况。

   假设当前shuffleRdd对应的shuffle ID =5, shuffleRdd之前的Rdd原始有4个分区，即map端原来有4个分区。

   数据分布为：

   executor 0上有数据块：shuffle5-m1-r0 的数据 20M，  shuffle5-m2-r0 的数据10M

   executor 1上有数据块：shuffle5-m3-r0 的数据 10M

   executor 2上有数据块：shuffle5-m4-r0 的数据 15M

2. 假定设置一个请求最多请求15M数据，当前executor2 需要shuffleRdd p0的数据的请求可以分为

   FetchRequest: 

   [e0, shuffle5-m1-r0] 向executor 0请求shuffle5-m1-r0的数据

   [e0, shuffle5-m2-r0] 向executor 0请求shuffle5-m2-r0的数据

   [e1, shuffle5-m3-r0] 向executor 0请求shuffle5-m2-r0的数据

   LocalRequest:

   [e2, shuffle5-m4-r0] 本地读取shuffle5-m4-r0的数据



   这里注意，图上有点画错了。。。

   注意到executor 0上的两个block被划分成了两个单独的request 是因为Spark有个参数限制每个request的数据上限，此处我假定为20M.而通过MapOutput里我们知道executor0上shuffle5-m1-r0 这个block就已经是20M了，因此单独切分成为一个request.

   看到这里，也就能理解为甚MapOutput里只记录了有哪些block以及这些block的大小。 因为下游reduce端之需要从driver处得到这些信息。

3. 这些request的返回结果要么是本地文件流（local request），要么是远端的输入流（fetchrequest），背后对应的都是shuffleRdd p0的部分数据。



   这一步值得提一下的是，当一个executor收到一个请求说，我需要读取shuffle5-m0-r0 的数据请求时， executor是如何找到这个对应的数据块的呢？

   对了，就是之前记录的 indexFile, 首先找到shuffle5-m0这个数据块，之后通过indexFile快速定位到r0的数据区域。




 ![sample](https://raw.githubusercontent.com/fuqiliang/review/master/share/spark/reader_more_specific.png)

#### 4.2 Aggeration ? Sort ?

 当reader拿到数据之后，比如我们定义sql 需要sort by groupId ， 而从readerIterator 获取的数据是多个block之间打乱的，那么，如何保证整个reduce partition0的数据是有序的呢？

或者我们需要对同样的key进行聚合操作，那么这些散落的数据是如何在reader处进行集合的呢？

Spark 2+里在reduce端对数据进行聚合、排序的方法跟sortShuffleReader一样，在代码上都是重用了ExternalSorter，利用hashtable+外部排序的思想，完成对大数据的聚合+排序。

具体可以参见https://www.jianshu.com/p/50278b0a0050

####  Reference

1. my slide :https://fuqiliang.github.io/review/share/spark/
2. [spark-shuffle,some dicusson on writer compare and memory setting, a little old](https://0x0fff.com/spark-architecture-shuffle/)
3. [shuffle_reader, detail go through code](https://www.jianshu.com/p/50278b0a0050)
4. [A whole gitbook, comparison with hadoop, a little old](https://spark-internals.books.yourtion.com/markdown/4-shuffleDetails.html)
5. [detail on shufflewriter, old but detail, almost work for spark2](https://www.cnblogs.com/itboys/p/9201750.html)
6. [memory discussion](https://www.ibm.com/developerworks/cn/analytics/library/ba-cn-apache-spark-memory-management/index.html)

