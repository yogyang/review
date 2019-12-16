
- [Structured Streaming 入门](#structured-streaming---)
  * [Sample](#sample)
  * [结果输出](#----)
    + [Complete Mode](#complete-mode)
    + [Update Mode](#update-mode)
    + [Append Mode](#append-mode)
    + [WaterMark && Window](#watermark----window)
  * [GroupState](#groupstate)
    + [UpdateStateFn](#updatestatefn)
    + [GroupStateTimeout](#groupstatetimeout)
      - [ProcessTimeout](#processtimeout)
      - [EventTimeout](#eventtimeout)
      - [Timeout 触发](#timeout---)
  * [Codes](#codes)

##  Structured Streaming 入门

先读一把[官方指南](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html#output-modes)

本文知识其中一些知识点，以自己的方式进行组织理解。

### Sample

Spark structured stremaming是隔一段时间，触发一次trigger，拉一批数据，称之为一个Batch。

单个Batch在抽象上可以看成一个源RDD，通过一些transformation,会最终编程finalRDD.writeStream.

对于单个Batch的处理，可以理解成一个小批处理，也就是对应着一个具体的SparkPlan. 而说到底一个SparkPlan在执行上会变成多个stage,说到底就是对一些数据进行一些fun操作。

比方说，简单的对输入流按照user_id进行消息数目统计，示例输入流为kafka, kafka 消息格式如下

```
user_id:1;2019-12-07 15:58:39.521334;event_number_1
```

通过一些对RDD里每个line的转换，将输入的batch转成DataSet[RawMsgEvent]

测试发送的顺序, 往kafaka里投递消息由一个单独的python脚本完成，每次执行一个脚本，可以触发一个batch

[user1, user2, user3] -> [user1] -> [user1, user2]

```scala
case class RawMsgEvent(
                      userId: String,
                      time: Timestamp,
                      event: String
                      )
```

将finalDF设定成groupByKey(_.userId).count()，输出console

```scala
  val finalDF = df.groupByKey(_.userId).count()
  val consoleOutput = finalDF.writeStream
        .outputMode(OutputMode.Complete())
      .queryName("testStreaming")
      .format("console")
      .start()

   consoleOutput.awaitTermination()
```

在这个示例中，会触发3个trigger,对应着3个Batch对应的输入数据如下
```

Batch 1 -> {

user1,xxx,xxx

user2,xxx,xxx

user3,xxx,xxx

}

Batch2 - > {user1, xxx, xxx}

Batch3 -> {

user1, xxx,xxx

user2, xxx, xxx

}
```

可以发现，Batch2 以及 Batch3的输入对结果的影响是不一样的

> Batch2只会影响user1的统计结果
>
> Batch3只会影响user1, user2的统计结果

对于后续流输入对结果的影响处理，又可以引入outputMode这个概念

### 结果输出

> - **Append mode (default)** - This is the default mode, where only the new rows added to the Result Table since the last trigger will be outputted to the sink. This is supported for only those queries where rows added to the Result Table is never going to change. Hence, this mode guarantees that each row will be output only once (assuming fault-tolerant sink). For example, queries with only `select`, `where`, `map`, `flatMap`, `filter`, `join`, etc. will support Append mode.
> - **Complete mode** - The whole Result Table will be outputted to the sink after every trigger. This is supported for aggregation queries.
> - **Update mode** - (*Available since Spark 2.1.1*) Only the rows in the Result Table that were updated since the last trigger will be outputted to the sink. More information to be added in future releases.

对于这个sample来说，我们在输入流上进行了简单的聚合，后续的trigger会影响最终的统计结果，所以此时，是无法用Append模式的。

而对应的Update和Complete非常好理解，Update只会输出最新一次的trigger影响了的数据，而Complete等于把最新trigger后，所有的计算结果都输出。即一个增量，一个全量。

实际看一下效果：

#### Complete Mode

每次都会将全量的数据输出，该模式也只能用在aggregate的情况下。

![image-20191208170707284](<https://raw.githubusercontent.com/yogyang/review/master/big-data/spark/streaming/pic/image-20191208170707284.png>)



#### Update Mode

 在Batch2以及Batch3中，只输出对应更新过的结果数据

![image-20191208170950940](<https://raw.githubusercontent.com/yogyang/review/master/big-data/spark/streaming/pic/image-20191208170950940.png>)


#### Append Mode
那么append就不能用在aggregate上了么？
答案是否定的！ 好歹也是默认模式。
回看Append的定义，有一句非常重要的话

> **This is supported for only those queries where rows added to the Result Table is never going to change. **

对，就在于如何看待或者说生成不会变的结果集合。

> 问：回看示例里，为什么(userid, count)这个结果表，可以一直变？
>
> 答： 因为流是unbounded，是源源不断的，数据是一直过来的，你没有办法保证后续不会再有某个userid的数据进来。

对的，流的数据是源源不断的，但是如果我们将计算的的数据范围给限定死，那么，就可以将某个result table的结果给限定死。

对应例子来说，我们目前计算的result table 对应的是**整个流数据的计算结果**，那当然无法保证结果不变。

如果我们将整个流的result table按时间段进行拆分，拆成为上午 10:00 -10:30的输入数据里(userid, count)，上午（10:30-11:00）的输入数据里(userid, count)，那么如果假设数据都是**准实时**到达的，那么到了10:31, 我们是不是就可以任务(10:00-10:30)的数据都已经统计完毕，统计结果不会再变了，那么就可以用append模式，输出这个已经不会再变的统计结果了！

#### WaterMark && Window

说到这，又会引入两个知识点，

1. 如何将数据按照时间段进行拆分 -> window

2. 刚刚我们假设是准实时，然后，真实情况是不可能准实时的。总会出现10:15的数据，结果11:00 甚至12:00才到。这个又牵扯到event_time & process_time，其实比较简单，没什么好说的。那么，我们到底什么时候才能判断（10:00-10:30）的数据都到了呢？

   答案就是watermark, watermark可以理解成业务逻辑上强制指定的**有效数据**最长延迟时间。比如，现在我们要统计(10:00-10:30)，我们设定watermark为30min。那么也就是说，业务上任务，在11:01分以后，不会再有有效的（10:00-10:30)的数据过来了。也就是说11:01 分以后，对于(10:00-10:30)这个窗口的统计来说，不会再有输入了，也就是说，对于这个窗口，一切已成定局。

   watermark对于业务来说，是一个过来掉延迟太长的无效流数据的一个办法。如果watermark不跟window/state搭配使用，我感觉也就是一个过滤无效数据的功能。

   而对于spark本身,也以为这哪些结果已成定局，可以直接输出给下游，而不需要继续在自己的内存中保存中间状态了。即什么时候，可以释放自己的空间。

   其实这也是Append模式的优点，数据不变-> 输出sink -> 内存释放。

   Complete模式，则刚好是另外一个极端，所有的就算是不变的结果，因为下次trigger的时候都需要写入sink，那么所有的数据都需要spark存在内存中。

   
### GroupState

之前的示例是一个无状态的计算，怎么说他无状态呢？之前不也说过中间结果啥的么？

![image-20191208175917468](https://raw.githubusercontent.com/yogyang/review/master/big-data/spark/streaming/pic//image-20191208175917468.png)

示例计算模型(我理解)可以简单画成如上图，

其中fun就是开发者写的那些transformation最后生成的一些 code.

对每个batch进行这些无状态的fun计算，这是一个纯粹的函数式过程，给一些输入对应一些输出，即batch->tmp这个过程。

之后，由Spark来进行跟上一次结果的聚合，比如(userid_1,1) + (userid_1, 1) -> （user_id1, 2），这个过程对于开发者来说，是不可见的。

那么当我们说Append Mode 可以丢弃中间状态时候，说的是绿色的部分，当某个RT1已经铁定不会再变了，也就是后续计算中不需要用到它了，那么它就可以直接sink出去，且内存删除。

所以，这里说的**无状态计算，是对开发者而言的，开发者传入的fun是不关心之前整个流的状态的。**

那么what if开发者的函数要装心整个数据的状态呢？

比如，简单的，如果user_id的消息累加到5个，那么我们就给user_id推送一条消息"xxxx, 你真棒！"？

这个应用的fun实现上就需要关心当前流里对应user已经累计了多少个事件了。

这种场景下，Spark提供了[GroupState](https://spark.apache.org/docs/2.2.0/api/java/org/apache/spark/sql/streaming/GroupState.html).

调用示范

```scala
val finalDF = df
      .groupByKey(_.userId)
      .flatMapGroupsWithState(OutputMode.Update(), GroupStateTimeout.EventTimeTimeout())(updateStateFn)
```



这个逻辑可以描述如下

1. 每次trigger触发一个Batch 
2. 每次的Batch根据key值分成不同的Group,  比方第一次G1, G2,G3. 第二次trigger的时候就对应成G1', G2', G3'.当然，如果第二个batch里没有K2的值，那么也不会有对应的G2‘。
3. 每次trigger的时候，分别对每个group进行updateStateFn调用, updateStateFn就包含了你要怎么处理这次group  events的逻辑
4. G1，G1'是跨时间的，那么他们之间共用一个GroupState1来共享一些状态信息，比如k1已经累计了多少个msg event.

![image-20191208182347796](https://raw.githubusercontent.com/yogyang/review/master/big-data/spark/streaming/pic/image-20191208182347796.png)

每个userId的msg event累计5次，输出一个Payload的示范

首先updateStateFn函数签名（keyname, 当前batch里该key的输入数据，group对应的GroupState，这次batch对应的结果输出

首先，代码逻辑是

1. 若当前group已经有一个state,那么累加event count, 按照event count数目生成对应的输出，每5个event就生成一个payload，写入下游sink
2. 若group没有，则初始化state.

```scala
def updateStateFn(
                   userId: String,
                   events: Iterator[RawMsgEvent],
                   state: GroupState[UserMsgState]
                   ): Iterator[PayLoad] = {
    if (state.hasTimedOut) {
      val finalState = state.get
      logger.info("session timeout for userId " + userId)
      state.remove()

      //Iterator(finalState)
      convertStateToPayLoad(finalState)._1
    } else {
      val currentState = state.getOption
      val aggregatedState = events.foldLeft(currentState)(
        (state, event) => {
          state.orElse{
            logger.info("created new state as no state for userid " + userId)
            Some(UserMsgState(event.userId, event.time.getTime, 0))
          }.map{
            s => s.increaseEventCount()
          }.map{
            s => s.updateMaxTimeMs(event.time.getTime)
          }
        }
      ).get

      val (payLoads, payLoadCount) = convertStateToPayLoad(aggregatedState)
      state.setTimeoutTimestamp(aggregatedState.maxTimeMs, "2 minutes")
      state.update(aggregatedState.decrementBy(5 * payLoadCount))
      //Iterator(aggregatedState)
      logger.info("Payload lenth for this batch:" + payLoadCount)
      logger.info("updated state:" + state.get)
      payLoads

    }
  }
}

```

#### UpdateStateFn

这个函数，Doc有说明好几个点：

-  In a trigger, the function will be called only the groups present in the batch. So do not assume that the function will be called in every trigger for every group that has state. 

-  There is no guaranteed ordering of values in the iterator in the function, neither with batch, nor with streaming Datasets. All the data will be shuffled before applying the function.

-   If timeout is set, then the function will also be called with no values. See more details on `GroupStateTimeout` below.


简而言之就是，batch有数据才会执行，events无顺序保证（对于每个batch来说，groupBy引发shuffle），statetimeout时候，events为空。

#### GroupStateTimeout

比方说10:00的时候，来了user1的数据，创建了对应的state1. 之后，再也没有user1的数据过来了，难道state1就要一直存在spark里么？

因为对于state来说，就有个timeout的概念，即一个state会保留多久。当state过期时候，也会触发updateStateFn函数。

TimeOut也有两种类型：

1. ProcessTimeout: 就是简单的state创建之后，开始计算，多久后state过期

2. EventTimeout: 根据event_time来计算，有点类似于window,必须配合watermark来用。其实我理解上，就跟window一样，state.setTimeoutTimestamp(start_time, "2 minutes") 这就定义了一个类似于window的概念，配合watermark来说明，什么时候state的数据不会再更新，也就是什么时候可以将该state淘汰了。

我们来实验一下, kafa msg流发送，开始发送user1，之后每隔1s发送user2的数据
```
[user1] -> [user2] -> [user2] -> [user2]
```
第一次发user1，之后只发user2.

##### ProcessTimeout

ProcessTimeout下设定

```scala
val finalDF = df
      .withWatermark("time", "2 minutes")
      .groupByKey(_.userId)
      .flatMapGroupsWithState(OutputMode.Update(), GroupStateTimeout.ProcessingTimeTimeout())(updateStateFn)


state.setTimeoutDuration("2 minutes")
```

实验结果：

2min之后stateg过期

```
2019-12-08 20:22:19 [INFO ] [com.kafkaToSparkToCass.Main$  :70] created new state as no state for userid user_id:1
...
2019-12-08 20:24:20 [INFO ] [com.kafkaToSparkToCass.Main$  :60] session timeout for userId user_id:1
2019-12-08 20:24:20 [INFO ] [com.kafkaToSparkToCass.Main$  :43] convert state to payload for state: UserMsgState(user_id:1,1575807730000,1)
```



##### EventTimeout

设定如下：

```scala
val finalDF = df
      .withWatermark("time", "2 minutes")
      .groupByKey(_.userId)
      .flatMapGroupsWithState(OutputMode.Append(), GroupStateTimeout.EventTimeTimeout())(updateStateFn)
      
state.setTimeoutTimestamp(aggregatedState.maxTimeMs, "2 minutes")
```

结果：

我的消息基本是实时的，所有时间差基本就是2(duration) + 2(watermark delay) = 4分钟

```
2019-12-08 20:36:22 [INFO ] [com.kafkaToSparkToCass.Main$  :70] created new state as no state for userid user_id:1
...
2019-12-08 20:40:23 [INFO ] [com.kafkaToSparkToCass.Main$  :60] session timeout for userId user_id:1
```



##### Timeout 触发

另外，不管是哪种形式的timeout，都要注意只有有数据进来，才会触发timeout。

如果说，kafka 流是 发完user1之后，就没有任何数据输入，那么state1的timeout不会被触发。



### Codes

<https://github.com/yogyang/spark-structured-streaming>

