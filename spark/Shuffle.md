##job need shuffle

[TOC]



由上节我们已知，spark中一个job的执行流程可简化为：

![屏幕快照 2018-10-22 下午11.10.58](/Users/yoga/Desktop/屏幕快照 2018-10-22 下午11.10.58.png)

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
![屏幕快照 2018-10-22 下午11.11.53](/Users/yoga/Desktop/屏幕快照 2018-10-22 下午11.11.53.png)

在构建finalStage的时候，DAGScheduler从finalRDD(groupRDD)往前推算，查看是否需要建partentStages, 判断原则是依赖链上遇到ShuffleDependency即生成一个ShuffleStageMap.

那么，上述RDD依赖链即对应成以下stage DAG图
![屏幕快照 2018-10-22 下午11.12.14](/Users/yoga/Desktop/屏幕快照 2018-10-22 下午11.12.14.png)

切割重点在于
>1. getShuffleDependencies: 切割算法即通过finalRDD进行深度遍历，找到最近的父级ShuffleDependency
>  即对于如下RDD链
>  ![屏幕快照 2018-10-22 下午11.12.35](/Users/yoga/Desktop/屏幕快照 2018-10-22 下午11.12.35.png)
>  对D1 调用 getShuffleDependencies => [B3, C2]


>2. 对1得到的shuffleDependencies构建ShuffleMapStage

### 2. submit stage

#### 2.1 ShuffleMapStage

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

| ResultTask.runTask     | func(context, rdd.iterator(partition, context))              | 对对应的partition数据进行 定义的func 调用 |
| ---------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| ShuffleMapTask.runTask | writer=manager.getWrite(dep.shuffleHandle, partitionId, context); writer.write(rdd.iterator(partition, context)) | 根据**shuffleDependency**生成ShuffleWriter,对对应的parition进行shuffle write |
从上述执行可以看出，ResultTask的核心在与func, ShuffleMapTask的核心在于dep.shuffleHandle，这两者都直接决定了后续task的执行逻辑。而这两者都是通过之前taskBinary里反序列化解析得到的。

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

在Spark 2.0+ 以后，Spark提供了三种shuffleWriter, BypassMergeSortShuffleWriter,UnsafeShuffleWriter,SortShuffleWriter.分别对应这上述三种handler. 

首先对于一个shuffle来说，数据的处理是分成了两步的，即map和reduce。 最简单的例子，比如([a1,b1,c1],[a2,b2,c2], [a3,b3,c3]
1. write: 也就是对应着map这个概念，map端一个partiton中的数据根据你的函数策略会对应成
![屏幕快照 2018-11-19 下午11.35.17](/Users/yoga/Desktop/屏幕快照 2018-11-19 下午11.35.17.png)

而整个逻辑下推，可以得到如下shufflewriter的生成策略：

![屏幕快照 2018-11-19 下午11.31.25](/Users/yoga/Desktop/屏幕快照 2018-11-19 下午11.31.25.png)
下面对应每个wirter我们来分别描述。



#####  BypassMergeSortShuffleWriter
该writer的策略为
![屏幕快照 2018-11-19 下午11.43.02](/Users/yoga/Desktop/屏幕快照 2018-11-19 下午11.43.02.png)