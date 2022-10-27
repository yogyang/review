# 从delta + optimize + gen\_manifest的bug聊起

开端是工作中碰到的一个问题，背景是

1. job1: 数据通过etl/streaming一直写入delta table `db1.tb1`, 数据按照（date,hour）分区
2. job2: 执行`optimize db1.tb1 where date='target_date'； vaccume db1.tb1;`

由于数据需要暴露给Redshift进行查询，因此，我们需要用特定的manifest来告诉 Redshift正确的数据分区信息，详细参见[https://docs.delta.io/latest/redshift-spectrum-integration.html](https://docs.delta.io/latest/redshift-spectrum-integration.html)。基本原理是，对于每个分区数据，有一个manifest文件列了该分区下valid parquet files, 并告诉Redshift我们现在有x分区，x分区执行-> manifest文件->parquet file lists. 这个manifest 文件，其实就是一个Redshift可以识别的分区文件索引。

所以，为了让Redshift能准确读取delta格式的数据，我们还需要格外的任务。

3\. job3: update 每个partition manifest文件，这个我们通过 delta自己的配置，让其在每个commit之后自动增量更新被影响的manifest文件。

```
delta.compatibility.symlinkFormatManifest.enabled=true
```

4\. job4: add/remove partitions to Redshift



这个workflow开始运行得没有什么问题，直到一两个星期后，线上偶尔发现，有些表通过Redshift读取，某些partition指向得数据parquet文件已经丢失。

也就是说，manifest的文件中，parquet文件列表不对。

当时第一反应是，manifest执行的文件是被vaccum掉的小文件，也就是说，optimize之后，delta的自动gen\_manifest并没有正确的把manifest更新，导致，manifest里依旧指向optimize的小文件，而不是合并之后的大文件。

#### 排查

可以发现，首先我们执行了一条optimize命令

`optimize db1.tb1 where date='2022-07-07'`

这条命令执行提交了3个commit，&#x20;

![](<../../.gitbook/assets/image (4).png>)

而从gen\_manifest日志里，也可以看到这3个commit对应触发的manifest更新

![](<../../.gitbook/assets/image (2).png>)

这里值得注意的是，commit1 和 commit2都更新了同一个partition, date=2022-06-28/hour=17&#x20;
