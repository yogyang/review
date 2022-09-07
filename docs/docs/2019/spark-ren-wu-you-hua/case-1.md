# Case 1

\[TOC]

**前言**

加入CF1个月，虽然工作跟自己想的有点差异，但倒也找到了有意思的点。 这一个月主要在看算法同学写的代码，帮忙看下有没有改进的点。这个事情其实还挺有意思的，去关注了挺多原来理不清的东西，目前做了3，4个case，记录下来。有些case挺简单的，但是探索的过程很有意思。

**Case1. 计算中间结果重用**

原代码如下，像将某一string列按照,拆分成多列：

```
for(i <- 0 to cols.length-1){
  df = df.withColumn(cols(i),split($"value","\\|")(i))
}
```

**线上现象**

1. GC占比十分严重,翻看container GC日志，可以发现young GC 频率极高。
2. GC日志里总可用堆大小一直是2G左右，而给executor设定的memory=10G

**代码问题**

这个问题其实挺明显，在于重复调用split() . 这种代码会导致大量的重复split操作发生，调用次数= cols.length \* record数目，那么本身数据量很大的时候，这种高频度的split调用会导致大量的Java临时对象产生，youngGC也会非常严重，改成复用split()的结果，线上从40min -> 10min.

查看SparkUI→SQL也可以看到，对于这种情况，Spark生成的QueryPlan里不会进行自动对split(value)进行复用，不知道对于这种SQL，Spark后续有没有自动优化的可能。 ![split\_multiple](https://raw.githubusercontent.com/fuqiliang/review/master/big-data/spark/Spark%E4%BB%BB%E5%8A%A1%E4%BC%98%E5%8C%96/pic/split\_multiple.png)

由于毕竟在给别的业务方做 code review，当业务方的逻辑过于复杂，不想先进行code review时候，可以先给executor.extraJavaOption传入-Xmn 扩大一下新生代比例，可以稍微解决一下GC的问题。

**改进**

代码改一下

```
val df = origin.withColumn("_tmp", split($"value", "\\|"))
val df2 = df.select(cols.indices.map(i => col("value")(i).alias(cols(i))) : _*)
```

查看新的QueryPlan ![split\_one](https://raw.githubusercontent.com/fuqiliang/review/master/big-data/spark/Spark%E4%BB%BB%E5%8A%A1%E4%BC%98%E5%8C%96/pic/split\_one.png)

**后序**

这个case其实挺简单的，但是有一个挺有意思的现象。 executor memory设定了10G之后，yarn 启动的jvm 进程中传入-Xmx 10G，然而默认的最小堆一直是1/64系统内存=2G。这就导致了GC日志里一直出现的可用堆大小2G，GC日志如图 ![gclog](https://raw.githubusercontent.com/fuqiliang/review/master/big-data/spark/Spark%E4%BB%BB%E5%8A%A1%E4%BC%98%E5%8C%96/pic/gclog.png)

这边有两个问题

1. GC日志里反应出的可用堆大小为2G，但是SparkUI里显示类似如下的（Storage+Execution)内存6G多，约等于10G \* memoryFraction. 所以说SparkUI 总显示的memory并不可信？
2. 从yarn container的启动命令来看，明确指定-Xmx 10G，即最小堆2G，最大堆10G。 而在这个case里，JVM在频繁young GC如此频繁的情况下并没有做堆扩容，JVM堆扩容的机制如何？ 且尝试指定-Xms 10G，直接会被yarn 拒绝。

**Reference**

1. JVM CMS GC： [https://blog.csdn.net/bmwopwer1/article/details/71947137](https://blog.csdn.net/bmwopwer1/article/details/71947137)
2. JVM ParNew + CMS GC: [http://ju.outofmemory.cn/entry/363883](http://ju.outofmemory.cn/entry/363883)
