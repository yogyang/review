---
typora-copy-images-to: ../worknote
---


### Zeppelin

EMR默认日志：/var/log/xxx
EMR默认配置:/etc/xxx/conf

启动Spark Interpreter log
```
INFO [2019-10-22 06:03:46,162] ({pool-2-thread-34} SparkInterpreterLauncher.java[buildEnvFromProperties]:113) - ZEPPELIN_SPARK_CONF:  --master
 yarn-client --conf spark.yarn.dist.archives=/usr/lib/spark/R/lib/sparkr.zip#sparkr --conf spark.jars='s3://jiayun.spark.data/yangjieyu/xgb_lr_
rank/xgboost4j-0.90.jar,s3://jiayun.spark.data/yangjieyu/xgb_lr_rank/xgboost4j-spark-0.90.jar' --conf spark.executor.memory='8g' --conf spark.y
arn.isPython=true --conf spark.app.name='Zeppelin-spark' --conf spark.driver.maxResultSize='2g' --conf spark.home='/usr/lib/spark'
 INFO [2019-10-22 06:03:46,162] ({pool-2-thread-34} SparkInterpreterLauncher.java[buildEnvFromProperties]:139) - Run Spark under non-secure mod
e as no keytab and principal is specified
 INFO [2019-10-22 06:03:46,162] ({pool-2-thread-34} RemoteInterpreterManagedProcess.java[start]:115) - Thrift server for callback will start. P
ort: 35493
 INFO [2019-10-22 06:03:46,663] ({pool-2-thread-34} RemoteInterpreterManagedProcess.java[start]:190) - Run interpreter process [/usr/lib/zeppel
in/bin/interpreter.sh, -d, /usr/lib/zeppelin/interpreter/spark, -c, 172.31.20.22, -p, 35493, -r, :, -l, /usr/lib/zeppelin/local-repo/spark, -g,
 spark]
```

集群A上Zeppelin Spark如何向集群B的yarn提交：
1. 将B的hadoop conf直接拷到A，A 的hadoop conf 重定向到新conf 


---

### Glue


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

#### hive 101

Hive就是一个SQL解析引擎，将SQL语句转化为相应的MapReduce程序

http://xiaqunfeng.cc/2018/10/18/Hive/

#### hive基本命令

show partitions table_name;
describe formatted external_pro_db.user_trace partition (log_date='2019-10-27');



------

### Spark

Spark GC 问题. 
http://ju.outofmemory.cn/entry/363883
https://blog.csdn.net/bmwopwer1/article/details/71947137
<<<<<<< HEAD
https://matt33.com/2018/07/28/jvm-cms/
=======

<https://umbertogriffo.gitbook.io/apache-spark-best-practices-and-tuning/chapter1/dont_collect_large_rdds>

>>>>>>> eb984be4f3128618f42d132709dba9c3f70769a0

1. spark schdeuler delay一直很大. ms schduler delay
2. coalesce 貌似有时不生效，生效后 105个core,coalesce(100) scheduler delay还是比较大
3. peak execution memory. https://stackoverflow.com/questions/39503484/peak-execution-memory-in-spark
4. spark sql broadcast df 重用
   broadcast there is no enoufh space to build hash map

5. shuffle write/ cache的size会是shuffle write的2倍
   Shuffle Write Size / Shuffle Spill(Memory) / Shuffle Spill(Disk) 
   https://jaceklaskowski.gitbooks.io/mastering-apache-spark/spark-webui-StagePage.html
6. Spark内部何时回skip stages,有一些RDD自动cache了？  

#### functions

---

filter:

```
originDF.filter(col("gender") === "F") // === && ==
originDF.filter("gender == 'F'")

```

---

window:

```
import sparkSession.implicits._
    val originDF = sparkSession.read
      .option("header", false)
      .option("inferSchema", true)
      .format("csv")
      .load(inputPath)
      .toDF("name", "course", "grade")
      .withColumn("grade", col("grade").cast(DoubleType))
      .as[Record]

    val overCourse = Window.partitionBy("course")
    val df1 = originDF.withColumn("average_grade", avg("grade") over overCourse)
    df1.show(false)
    df1.printSchema()

    val df2 = originDF.withColumn("col_test", collect_list("grade") over overCourse.orderBy("grade"))
    df2.show(false)

    val overPerson = Window.partitionBy("name")
    val df3 = originDF.withColumn("avg_grade_person", avg("grade") over overPerson)
        .withColumn("avg_grade_course", avg("grade") over overCourse)
    df3.show(false)



    val df4 = originDF
      .withColumn("struct_test", struct(
        col("grade").alias("g"),col("course").alias("c")
      ))
        .groupBy("name")
        .agg(collect_list("struct_test").alias("array_s"))
        .withColumn("sort_array", sort_array(col("array_s")))
    df4.show(false)


```
https://knockdata.github.io/spark-window-function/

---

a. groupBy
b. cache源码
c. Spark堆外内存的使用 
d. spark dataframe filter => col("gender") === 'F'
e. repartionBy("c0_1",1000) -> 到底几个partition有数据，数据是如何分布的
f. spark 读取hive的多级目录失败，
g. spark locality_level https://www.jianshu.com/p/05034a9c8cae
h. collect_list with order


#### Spark元数据过期
```
java.io.FileNotFoundException: No such file or directory 's3://xxxxxx/date_id=2019-10-20/000002_0'
It is possible the underlying files have been updated. You can explicitly invalidate the cache in Spark by running 'REFRESH TABLE tableName' command in SQL or by recreating the Dataset/DataFrame involved.
```

https://github.com/cjuexuan/mynote/issues/32
https://blog.csdn.net/zyzzxycj/article/details/85166571

#### 内存爆

```
Container killed by YARN for exceeding memory limits. 11.1 GB of 11 GB physical memory used. Consider boosting spark.yarn.executor.memoryOverhead or disabling
```

#### EMR上SparkUIdriver里打印的ip:host不对
通过报错发现，ApplicationMaster对应的跳转链接为：http://ip1:4047，而airflow中显示的driver日志如下

INFO - Subtask: 19/10/31 08:49:39 INFO SparkUI: Bound SparkUI to 0.0.0.0, and started at ip1:4047

而通过Airflow调度执行的机器为 ip2，即spark-submit指定的机器IP为ip2,启动模式为yarn-client，所以SparkUI 的访问地址应该是ip2:4047
查看Spark源码可以发现，


查看/usr/lib/spark/conf/spark-env.sh可以看到，

EMR写死了PUBLIC_DNS,嗯, EMR 你真棒！

  
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

```
minute   hour   day   month   week   command 
星号（*）：代表所有可能的值，例如month字段如果是星号，则表示在满足其它字段的制约条件后每月都执行该命令操作。
逗号（,）：可以用逗号隔开的值指定一个列表范围，例如，“1,2,5,7,8,9”
中杠（-）：可以用整数之间的中杠表示一个整数范围，例如“2-6”表示“2,3,4,5,6”
正斜线（/）：可以用正斜线指定时间的间隔频率，例如“0-23/2”表示每两小时执行一次。同时正斜线可以和星号一起使用，例如*/10，如果用在minute字段，表示每十分钟执行一次。
```

每1分钟执行一次command  * * * * * command
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







