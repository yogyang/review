---
typora-copy-images-to: ../worknote
---





---

### hive

#### hive内表/外表
内表： 
create table zz (name string , age string) location '/input/table_data';
load data inpath '/input/data' into table zz;

外表：
create external table et (name string , age string); 
load data inpath '/input/edata' into table et; 

建表时带有external关键字为外部表，否则为内部表
内部表和外部表建表时都可以自己指定location
删除表时，外部表不会删除对应的数据，只会删除元数据信息，内部表则会删除



------

### Spark

Spark GC 问题. 
http://ju.outofmemory.cn/entry/363883
https://blog.csdn.net/bmwopwer1/article/details/71947137

<https://umbertogriffo.gitbook.io/apache-spark-best-practices-and-tuning/chapter1/dont_collect_large_rdds>


1. spark schdeuler delay一直很大. ms schduler delay
2. coalesce 貌似有时不生效，生效后 105个core,coalesce(100) scheduler delay还是比较大
3. peak execution memory. https://stackoverflow.com/questions/39503484/peak-execution-memory-in-spark
4. spark sql broadcast df 重用
   broadcast there is no enoufh space to build hash map

5. shuffle write/ cache的size会是shuffle write的2倍
   Shuffle Write Size / Shuffle Spill(Memory) / Shuffle Spill(Disk) 
   https://jaceklaskowski.gitbooks.io/mastering-apache-spark/spark-webui-StagePage.html

#### Spark优化案例

  1. 注意中间计算结果重用
  ```
  for (i <- 0 util len) {
  	df = df.withColumn("c"+i, $"value".split(",")(i))
  }
  ```

 这类问题会导致大量的重复split产生，且当$value本身数据很大时候，会导致大量的Java临时对象产生，youngGC也会非常严重，改成复用split()的结果，线上从40min -> 10min.

 当业务方由于逻辑过于复杂，不想先进行code review时候，可以先给executor.extraJavaOption传入-Xmn 扩大一下新生代比例，可以稍微解决一下GC的问题。这个案例中有非常有意思的发现，yarn启动的container并不会将Xms=Xmx,xms 默认还是1/64的机器内存，而且貌似JVM在老年代资源一直占据不多时，不会进行堆扩容。这就直接导致了线上任务一直处于可用堆2G，新生代大概500M的状况，加剧了GC的恶化。

  2. 输入数据本身倾斜很大
    最小16K，最大3.2G,任务数据分配极不均匀，最后job等3.2G的任务执行完就花了35min.
    将数据先进行repartition(500)后再运算，线上40min -> 20min. 其实单纯的数据repartition并不怎么耗时，在进行复杂的计算之前，越要注意数据均分。
    
  3. sql join 小表，嵌套groupby
      线上一条SQL类似
  ```
  select a, sum(price), sum(arrive), sum(xxxx)
     select a, b, sum(price)
		  from
		   (
		   	select a, c, sum(aColumnName)
		   	from (
		   		select a,b,aColumnName
		   		from t1
		   		) t2 group by 1,2
		   ) t3 join dimensionT
		   on t3.c = dimensionT.c
	   group by 1,2
   group by a
  ```
这条SQL很有意思，它在SparkUI里对应的SQL图和job stage图分别为

![SQL](/Users/yoga/Documents/workspace/review/worknote/SQL.png)

从SQL图可以看到，触发了SortMergeJoin,对应SQL的 join dimensionT on t3.c = dimensionT.c, 而且dimensionT输入才170M+,另外一张表200G+，也就是大表Join小表。SortMergeJoin会触发两个输入表按照c进行重分布的shuffle，即对应着stage 3 4.

![DAG](/Users/yoga/Documents/workspace/review/worknote/DAG.jpg)
从job stage图中，可以看出，每次group by 都出发了一次shuffle, 对应stage的5，6，7

这个任务的优化我从两个方面进行考虑
- 大表join小表，改成broadcast(小表)，即写成df.join(broadcast(dimensionT), "pid")
- SQL中的每次group by都是以a为开头，那么如果我一开始就把数据按照a进行repartition, 后面所有的group by都将变成窄依赖，将减少3次shuffle
  
---

### Yarn
a. 调度类型
   FIFO 先进先出，
   Capacity  https://www.jianshu.com/p/25788c6caf49. 如果队列中的资源有剩余或者空闲，可以暂时共享给那些需要资源的队列，而一旦该队列有新的应用程序需要资源运行，则其他队列释放的资源会归还给该队列（非强制回收）

   Fair调度：跟Capacity的区别？

b. 调度资源类型 ??

record:
https://zhuanlan.zhihu.com/p/28640358?from_voters_page=true
https://cloud.tencent.com/developer/article/1195056
https://cloud.tencent.com/developer/article/1194446
<https://mp.weixin.qq.com/s?__biz=MzUxMDQxMDMyNg==&mid=2247483866&idx=1&sn=7eb0d8e3ef5f8928842e6925084ac6d3&chksm=f9022ae3ce75a3f5c6a2648835c686e93776c4bfe5cdc54865635c8ac757f8464f105818ab46&mpshare=1&scene=1&srcid=1009w3nIiRWdcNNlrg5DWWtV#rd>


#### 运维相关
Q：Yarn node unhealthy，导致node下线，1/1 local-dirs are bad: /yarn/nm; 1/1 log-dirs are bad: /var/log/hadoop-yarn/container-logs
A：相应节点的本地磁盘目录写满，导致报警。 清理相应目录即可
   相关命令：

   ```
   df -lh
   sudo du -h --max-depth=1
   sudo su - yarn -c "rm -rf /mnt/yarn/usercache"
   df /var/log/hadoop-yarn/

   ```
   配置yarn nodemanager 自动clean cache : https://community.cloudera.com/t5/Support-Questions/Yarn-Automatic-clearing-of-filecache-usercache-not-kicking/td-p/120463

   http://www.inter12.org/archives/1169
   https://hadoop.apache.org/docs/r2.7.7/hadoop-yarn/hadoop-yarn-common/yarn-default.xml   

---

### Airflow


#### Crontab语法
minute   hour   day   month   week   command 
星号（*）：代表所有可能的值，例如month字段如果是星号，则表示在满足其它字段的制约条件后每月都执行该命令操作。
逗号（,）：可以用逗号隔开的值指定一个列表范围，例如，“1,2,5,7,8,9”
中杠（-）：可以用整数之间的中杠表示一个整数范围，例如“2-6”表示“2,3,4,5,6”
正斜线（/）：可以用正斜线指定时间的间隔频率，例如“0-23/2”表示每两小时执行一次。同时正斜线可以和星号一起使用，例如*/10，如果用在minute字段，表示每十分钟执行一次。

每1分钟执行一次command  * 20 * * * command
每小时的第3和第15分钟执行  3,15 * * * * command

---

### S3

#### EMRFS

```
emrfs sync s3://bucket/folder
emrfs delete s3://bucket/folder
emrfs diff s3://bucket/folder

```

#### 运维相关
Q：Spark写入S3,目录重写，发生一致性检查错误，集群开启了一致性检查
   原因是 有两个应用都在对该s3目录进行操作，一个应用运行在非一致性EMR集群，另一个应用运行在一致性集群。
   EMRFS 支持S3一致性优化实现其实是通过写DynamoDB记录源数据，通过写DynamoDB+s3桶的原子性来保证。
   非一致性集群对DynamoDB的存在无感知，在进行s3删数据时候，无法更新DynamoDB原数据信息







