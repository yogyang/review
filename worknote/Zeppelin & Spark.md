[TOC]
### Zeppelin & Spark
Zeppelin  提供了一个web界面让你直接运行各种计算引擎的计算任务，spark只是它支持的一个计算平台，代码里Spark Interpreter的方式，页面上以notebook %spark的形式提供给外部。

#### Spark Interpreter
``` scala
%spark
spark.sql("select * from hive_test2").show()
```

#####  SparkContext是否共享
![SparkInterpreter](/Users/yangyujia/Desktop/1.png)

在Interpreter设置中，可以设置SparkContext的共享级别：Global, per Note, per User

https://community.cloudera.com/t5/Support-Questions/How-to-avoid-sharing-spark-context-between-two-Zeppelin/td-p/226847


####  sh + Spark-submit
```
%sh

spark-submit \
--class category.online.ctr.ctr3.process_fea \
--master yarn \
--deploy-mode client \
s3://jiayun.spark.data/product_algorithm/category_online_ctr_tmp_data/online_ctr3/target/spark_job_product_algo-1.0.0-jar-with-dependencies.jar

```
这种方式下，应该以一个单独的spark任务提交的方式，会按照spark-submit的设定的方式，另外启动一个spark application.

### Questions
1. EMR spark historyServer  里，可以看到一些Incomplete的spark application, last updated 是最新的，但是在hadoop-yarn的资源管理器里running spark application里看不到该应用。 具体表现有：

   a.  Spark HistoryServer 可以看到该appication last updated还是最新的， 但是yarn Running Application里看不到该应用

   b. 点进该application Spark UI， 最近的数据更新都是一周之前了

   c. ssh到driver的机器上，可以看到driver jvm 进程还在，但是Spark UI上active的executor进程貌似已经不字啊了

   ```sh
   sudo lsof -i:35677
   ps aux | grep 94768
   ```

   d.  查看driver的启动命令以及日志

   从启动命令可以看出，是通过zeppelin 通过spark-submit提交的 yarn -client模式的spark application

   从driver输出日志看来，spark  application还在正常运行，且一直在提交一些job

   ```
   zeppelin  94768  0.1  1.0 11545800 1296520 ?    Sl   Sep25  24:49 /usr/lib/jvm/java-openjdk/bin/java -cp /usr/lib/zeppelin/local-repo/spark/*:/usr/lib/zeppelin/interpreter/spark/*:/usr/lib/zeppelin/lib/interpreter/*:/usr/lib/hadoop-lzo/lib/*:/usr/lib/hadoop/hadoop-aws.jar:/usr/share/aws/aws-java-sdk/*:/usr/share/aws/emr/emrfs/conf/:/usr/share/aws/emr/emrfs/lib/*:/usr/share/aws/emr/emrfs/auxlib/*:/usr/share/aws/hmclient/lib/aws-glue-datacatalog-spark-client.jar:/usr/share/aws/sagemaker-spark-sdk/lib/sagemaker-spark-sdk.jar:/usr/lib/zeppelin/interpreter/spark/spark-interpreter-0.8.1.jar:/etc/hadoop/conf/:/usr/lib/spark/conf/:/usr/lib/spark/jars/* -Xmx1g -Dfile.encoding=UTF-8 -Dlog4j.configuration=file:///etc/zeppelin/conf/log4j.properties -Dzeppelin.log.file=/var/log/zeppelin/zeppelin-interpreter-spark-zeppelin-ip-172-31-20-22.log org.apache.spark.deploy.SparkSubmit --master yarn-client --conf spark.executorEnv.PYTHONPATH=/usr/lib/spark/python/lib/py4j-src.zip:/usr/lib/spark/python/:<CPS>{{PWD}}/pyspark.zip<CPS>{{PWD}}/py4j-src.zip --conf spark.yarn.isPython=true --conf spark.home=/usr/lib/spark --conf spark.yarn.dist.archives=/usr/lib/spark/R/lib/sparkr.zip#sparkr --conf spark.driver.extraClassPath=:/usr/lib/zeppelin/local-repo/spark/*:/usr/lib/zeppelin/interpreter/spark/*:/usr/lib/zeppelin/lib/interpreter/*::/usr/lib/hadoop-lzo/lib/*:/usr/lib/hadoop/hadoop-aws.jar:/usr/share/aws/aws-java-sdk/*:/usr/share/aws/emr/emrfs/conf:/usr/share/aws/emr/emrfs/lib/*:/usr/share/aws/emr/emrfs/auxlib/*:/usr/share/aws/hmclient/lib/aws-glue-datacatalog-spark-client.jar:/usr/share/aws/sagemaker-spark-sdk/lib/sagemaker-spark-sdk.jar:/usr/lib/zeppelin/interpreter/spark/spark-interpreter-0.8.1.jar:/etc/hadoop/conf --conf spark.app.name=Zeppelin --conf spark.driver.extraJavaOptions= -Dfile.encoding=UTF-8 -Dlog4j.configuration=file:///etc/zeppelin/conf/log4j.properties -Dzeppelin.log.file=/var/log/zeppelin/zeppelin-interpreter-spark-zeppelin-ip-172-31-20-22.log --class org.apache.zeppelin.interpreter.remote.RemoteInterpreterServer /usr/lib/zeppelin/interpreter/spark/spark-interpreter-0.8.1.jar 172.31.20.22 34089
   ```

     executor 自动释放的日志：

   ```
   INFO [2019-10-08 05:40:10,673] ({spark-dynamic-executor-allocation} Logging.scala[logInfo]:54) - Removing executor 325 because it has been idl
   e for 60 seconds (new desired total will be 3)
    INFO [2019-10-08 05:40:10,730] ({dispatcher-event-loop-7} Logging.scala[logInfo]:54) - Disabling executor 319.
    INFO [2019-10-08 05:40:10,731] ({dag-scheduler-event-loop} Logging.scala[logInfo]:54) - Executor lost: 319 (epoch 1)
    INFO [2019-10-08 05:40:10,731] ({dispatcher-event-loop-9} Logging.scala[logInfo]:54) - Trying to remove executor 319 from BlockManagerMaster.
    INFO [2019-10-08 05:40:10,731] ({dispatcher-event-loop-9} Logging.scala[logInfo]:54) - Removing block manager BlockManagerId(319, ip-172-31-26
   -220.us-west-2.compute.internal, 40685, None)
   ```

   Job 被启动的日志:

   ```
    INFO [2019-10-08 05:40:15,855] ({dispatcher-event-loop-7} Logging.scala[logInfo]:54) - Executor 327 on ip-172-31-26-220.us-west-2.compute.internal killed by driver.
    INFO [2019-10-08 05:40:15,855] ({spark-listener-group-executorManagement} Logging.scala[logInfo]:54) - Existing executor 327 has been removed (new total is 0)
    INFO [2019-10-08 05:42:37,541] ({pool-3-thread-14} SchedulerFactory.java[jobStarted]:114) - Job 20191008-054229_394904915 started by scheduler interpreter_2100998730
    INFO [2019-10-08 05:42:37,621] ({pool-3-thread-14} SchedulerFactory.java[jobFinished]:120) - Job 20191008-054229_394904915 finished by scheduler interpreter_2100998730
    INFO [2019-10-08 05:48:17,857] ({pool-3-thread-7} SchedulerFactory.java[jobStarted]:114) - Job 20191008-054237_1889324758 started by scheduler interpreter_2100998730
    INFO [2019-10-08 05:48:17,951] ({pool-3-thread-7} SchedulerFactory.java[jobFinished]:120) - Job 20191008-054237_1889324758 finished by scheduler interpreter_2100998730
    INFO [2019-10-08 05:48:33,332] ({pool-3-thread-15} SchedulerFactory.java[jobStarted]:114) - Job 20191008-054817_502535408 started by scheduler interpreter_2100998730
    WARN [2019-10-08 05:48:33,494] ({pool-3-thread-15} Logging.scala[logWarning]:66) - Using an existing SparkSession; some configuration may not take effect.
    WARN [2019-10-08 06:09:21,966] ({pool-3-thread-41} HiveConf.java[initialize]:2756) - HiveConf of name hive.async.log.enabled does not exist
    WARN [2019-10-08 06:09:21,966] ({pool-3-thread-41} HiveConf.java[initialize]:2756) - HiveConf of name hive.optimize.ppd.input.formats does not exist
   ```

   看到SchedulerFactory: https://github.com/apache/zeppelin/blob/master/zeppelin-interpreter/src/main/java/org/apache/zeppelin/scheduler/SchedulerFactory.java

   so这种spark application是不是zeppelin提供的一直在定时触发spark job, 但是为什么yarn追踪不到而spark history server可以追踪到。

   

   







