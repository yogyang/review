title: Spark2+ Shuffle
author:
  name: Yujia Yang
  twitter: none
  url: https://github.com/jdan/cleaver
output: index.html
controls: true

--

# Spark2+ Shuffle

## Basic workflow and shuffle

--

### WorkFlow 

Let's start with basic job.
``` scala
val dataRdd = sc.parallelize(data, 3)
dataRdd.count()
```

In SparkContext
```
def runJob[T, U: ClassTag](
      rdd: RDD[T],
      func: (TaskContext, Iterator[T]) => U,
      partitions: Seq[Int],
      resultHandler: (Int, U) => Unit): 
```

In DAGScheduler

```
def submitJob[T, U](
      rdd: RDD[T],
      func: (TaskContext, Iterator[T]) => U,
      partitions: Seq[Int],
      callSite: CallSite,
      resultHandler: (Int, U) => Unit,
      properties: Properties): JobWaiter[U]
```

--

### Simple View From Driver

<img src="https://note.youdao.com/yws/public/resource/30539e78e5e0de8aa8717d15f6dc2003/xmlnote/WEBRESOURCE85775074b5e88906b00890485e61318c/3619?ynotemdtimestamp=1542681791032" alt="drawing" width="800" height="350"/>

```
1. driver端，DAGScheduler 会对job进行提交，且对job生成一个JobWaiter, 而JobWaiter的阻塞和唤醒就分别对应着job的阻塞和完成。
2. rdd : 描述了之前所有的transformation依赖关系
3. func : 描述了你的算子操作
4. parititions: 计算哪些parition
5.resultHandler: 每个partition的计算结果如何汇总
```

--

###  WorkFlow Over Cluster
<img src="https://note.youdao.com/yws/public/resource/30539e78e5e0de8aa8717d15f6dc2003/xmlnote/WEBRESOURCE0caf9a20da2f000e5c5bacafb1aa15db/4005?ynotemdtimestamp=1542685679547" alt="drawing" width="800" height="400"/>

```
step 1. stage拓扑图中只有一个ResultStage
step 3. executor 执行task之后，将结果直接发回给driver
step 4. driver在接收到所有的task的结果后，对JobWaiter进行唤醒， 在driver端对所有的result 按照result handler进行处理。

```

--

### A job with Shuffle

basic code
```
val dataRdd = context.parallelize(data, 3)
val groupRdd = dataRdd.groupBy(r => r.getInt(0))
val count = groupRdd.count()
```

basic workflow 
```
create stage 
-> submit stage
-> stage to tasks 
-> task execute 
-> result send back 
-> next stage
```

--

### Create Stage DAG

```
在真正做action之前，我们通过一系列的transformation得到了一个finalRDD，本例中即groupRDD,之后我们在groupRDD上触发一个action,才真正得开始向spark提交一个job.

通过RDD的dependencies，我们已知groupRDD的依赖链
```
<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/rdd_dependency.png?token=AAAENajQcZ7jU-jnuukuCbP7pYmKuj1Bks5b_VqNwA%3D%3D" alt="drawing" width="800" height="150"/>

```
构建finalStage的时候，DAGScheduler从finalRDD(groupRDD)往前推算，
查看是否需要建partentStages, 
判断原则是依赖链上遇到ShuffleDependency即生成一个ShuffleStageMap
```

<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/stage_cut.png?token=AAAENUpPgH2F6DdZkpSz66kDQvEYurYdks5b_VtwwA%3D%3D" alt="drawing" width="800" height="200"/>

-- 

### submit stage
```
由上述可知，对于示例程序来说，DAG拓扑图构成为ShuffleMapStage->ResultStage. 
DAG 拓扑图生成后，我们来到step2 - submitStage(finalStage).

submitStage的流程之前说过, 核心归结为一句话：
Submits stage, but first recursively submits any missing parents

先检查该stage是否有依赖的parentStage没有执行，
若有 ->  先submit 所有的parentStage, 该stage 加入waitingStage set中
若无 ->  直接submit该stage

本例中，由于父stage stage_1的存在，程序会先submit stage_0.
注意跟之前no_shuffle_job 的submit stage最大一个区别来了：

提交的stage为 **ShuffleMapStage**
```

--

### stage to tasks

#### ResultStage -> ResultTask

![resultstage-> task](https://github.microstrategy.com/raw/yujyang/share/master/spark/resultstge2task.png?token=AAAENYQ0CgayTByryizvqhsA6aQwCpu-ks5b_1tawA%3D%3D)

--

### stage to tasks

####  ResultTask

<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/resultTask.jpg?token=AAAENXtYLnlRud7EsKSnwCJ59sE5ITmRks5b_1uOwA%3D%3D" alt="drawing" width="800" height="300"/>

--

### Shuffle

![shuffle](https://github.microstrategy.com/raw/yujyang/share/master/spark/shuffle.png?token=AAAENQ-_3dUuSoN8B8Oh8L_ME7I0-Q7Iks5b_1vJwA%3D%3D)

```
数据的重分布，重点在乎数据，不在于一个计算结果

Map 和 Reduce =>  ShuffleMapTask  和  ShuffleRdd.compute
```

<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/stage_cut.png?token=AAAENUpPgH2F6DdZkpSz66kDQvEYurYdks5b_VtwwA%3D%3D" alt="drawing" width="800" height="200"/>

---

####  ShuffleMapTask

<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/shuffleMapTask.jpg?token=AAAENb2cIqjzHkERDWhibsKvynyYcvC0ks5b_1w-wA%3D%3D" alt="drawing" width="800" height="300"/>

```
1. MapStatus: Includes the block manager address that the task ran on as well as the sizes of outputs for each reducer, for passing on to the reduce tasks.
2. ShuffleWriter
3. ShuffleDependency

```

--

#### ShuffleDependency 
```
首先一个问题，这个stage.shuffleDep是什么时候生成的？

回到RDD的依赖链，DAG拓扑图就是根据依赖链里的ShuffleDependency进行切割的。
所以ShuffleDependency和ShuffleRDD是1对1 的，
这是一个ShuffleRDD的固有属性值，
每个ShuffleRDD生成的时候，其对应的ShuffleDependency该如何就已经确定了。
```

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

---

#### ShuffleWriter

![shufflewirterGenral](https://github.microstrategy.com/raw/yujyang/share/master/spark/shuffle_writer_general.png?token=AAAENednk2Fsshfi6DFq38s1GqD5EJPyks5b_11LwA%3D%3D)

---
#### ShuffleWriter

<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/shuffledependency2writer.png?token=AAAENf0wffL5NTxnFXVfNxWieOn-R5j3ks5b__eGwA%3D%3D" alt="drawing" width="800" height="150"/>

<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/shufflewriter_dispatch.png?token=AAAENUa7M3nPF7Fjcfwlp7wJ22BCmzysks5b_11rwA%3D%3D" alt="drawing" width="800" height="350"/>

---

#### BypassMergeSortShuffleWriter

<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/bypassmerge.png?token=AAAENRdVXXgi5da69uzJjaL-CvbtH6_Wks5b__fFwA%3D%3D" alt="drawing" width="1000" height="300"/>

<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/bypassmergeShufflerWriter.png?token=AAAENY5Qhoz6Crj1vdySLbJTTPt-tfK0ks5b_12xwA%3D%3D" alt="drawing" width="800" height="200"/>

--

#### SortShuffleWriter

<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/sortshuffle.png?token=AAAENeNV4sLf1t35bYrcUZj_kbslrK6Kks5b__fmwA%3D%3D" alt="drawing" width="1000" height="400"/>

```
1. algorithm : external sort , heap sort
2. support : aggregation, sort by (partitonId, order)
```

[detail_url](https://www.cnblogs.com/itboys/p/9201750.html)

---

#### UnSafeShuffleWriter

<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/unsafeShuffle.png?token=AAAENXslXtNJ0s3TC0X8nHvj-TnocILFks5b__gAwA%3D%3D" alt="drawing" width="1000" height="500"/>

```
1. copy bytes，avoid serialize and deserialize
2. no aggeration
```

[Reference](https://www.cnblogs.com/itboys/p/9201750.html)

--

#### Map to Reduce

<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/mapoutput2driver.png?token=AAAENbJDsJSWZ0FJv3UG8C7xyZ6E-4vdks5b_4HZwA%3D%3D" alt="drawing" width="800" height="200"/>


```
Now ShuffleStage done,  Go to submit next stage, in our example, it's a ResultStage
```
<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/nextstagshuffleRdd.compute.png?token=AAAENT7zu7SYnPAd55hVQ9slyTIlmIBcks5b_4HvwA%3D%3D" alt="drawing" width="800" height="200"/>


**ShuffleReader**

---

#### BlockStoreShuffleReader

<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/reader_Logic.png?token=AAAENfMvV0RkffINYq27bQxdumRUhsPbks5b_4IYwA%3D%3D" alt="drawing" width="800" height="500"/>


---

#### BlockStoreShuffleReader

<img src="https://github.microstrategy.com/raw/yujyang/share/master/spark/reader_more_specific.png?token=AAAENRMk8B1zPfR5Cpuid_Yzzxs3LGV0ks5b_4I8wA%3D%3D" alt="drawing" width="800" height="500"/>

---

#### BlockStoreShuffleReader -  Aggeration ? Sort ?


Same to SortShuffleWriter

Reference : [shuffle_reader](https://www.jianshu.com/p/50278b0a0050)

----

#### Question 

Reference:

[spark-shuffle,some dicusson on writer compare and memory setting, a little old](https://0x0fff.com/spark-architecture-shuffle/)

[shuffle_reader, detail go through code](https://www.jianshu.com/p/50278b0a0050)

[A whole gitbook, comparison with hadoop, a little old](https://spark-internals.books.yourtion.com/markdown/4-shuffleDetails.html)

[detail on shufflewriter, old but detail, almost work for spark2](https://www.cnblogs.com/itboys/p/9201750.html)

[memory discussion](https://www.ibm.com/developerworks/cn/analytics/library/ba-cn-apache-spark-memory-management/index.html)