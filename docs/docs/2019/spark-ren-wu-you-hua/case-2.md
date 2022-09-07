# Case 2

\[TOC]

**Case2. 输入数据倾斜**

由于源表数据输入数据分文件存储，最小16K，最大3.2G,任务数据分配极不均匀，最后3.2G的任务执行完就花了35min，整个job都在等这最后一个任务执行。

将数据先进行repartition(500)后再运算，线上40min -> 20min.

其实根据线上的经验来看，100G的数据单纯repartition在线上50container \* 3core \* 10G memory下只要3，4分钟的样子，这种数据量的单纯数据repartition并不怎么耗时，在进行复杂的计算之前，越要注意数据均分。

**问题**

有个问题挺好奇的，这个输入是s3上很多的单文件，输入的partition大小从16k -> 3.2G。

像比如spark读取一个3G的问题，为啥没有按照一些默认的block大小进行分区？比方说128M 一个partition?3.2G一个分区是如何搞出来？

关于这个问题，刚好看到一个解释，来源 [http://www.jasongj.com/spark/skew/](http://www.jasongj.com/spark/skew/)

```
Spark以通过textFile(path, minPartitions)方法读取文件时，使用TextFileFormat。

对于不可切分的文件，每个文件对应一个Split从而对应一个Partition。此时各文件大小是否一致，很大程度上决定了是否存在数据源侧的数据倾斜。另外，对于不可切分的压缩文件，即使压缩后的文件大小一致，它所包含的实际数据量也可能差别很多，因为源文件数据重复度越高，压缩比越高。反过来，即使压缩文件大小接近，但由于压缩比可能差距很大，所需处理的数据量差距也可能很大。

此时可通过在数据生成端将不可切分文件存储为可切分文件，或者保证各文件包含数据量相同的方式避免数据倾斜。

对于可切分的文件，每个Split大小由如下算法决定。其中goalSize等于所有文件总大小除以minPartitions。而blockSize，如果是HDFS文件，由文件本身的block大小决定；如果是Linux本地文件，且使用本地模式，由fs.local.block.size决定。

protected long computeSplitSize(long goalSize, long minSize, long blockSize) {
    return Math.max(minSize, Math.min(goalSize, blockSize));
}
默认情况下各Split的大小不会太大，一般相当于一个Block大小（在Hadoop 2中，默认值为128MB），所以数据倾斜问题不明显。如果出现了严重的数据倾斜，可通过上述参数调整。
```

对应这个问题，发现确实，这个case里输入的文件都是csv.gz，不可分割的压缩文件。

作者给的代码入口就是HadoopRDD.getPartition -> FileInputFormat.getSplits

![image-20191027212551556](https://raw.githubusercontent.com/fuqiliang/review/master/big-data/spark/Spark%E4%BB%BB%E5%8A%A1%E4%BC%98%E5%8C%96/pic/case2\_1.png)

线上读取的s3文件，应该s3对应的实现。

我在本地用csv.zip去试了这一段逻辑，还挺奇怪的，zip被识别了splitable = = 嗯。。

**Reference**

1. Spark 数据倾斜: [http://www.jasongj.com/spark/skew/](http://www.jasongj.com/spark/skew/)
