## EMR运维

[TOC]

---

### Yarn
/mnt/var/log/hadoop-yarn/containers
/mnt/var/log/tmp/var/log/hadoop-yarn/containers/
gzip XXX.gz -d 

sudo su  -c "gzip -d /mnt/var/log/tmp/var/log/hadoop-yarn/containers/application_1571216922451_0033/container_e26_1571216922451_0033_01_000004/stderr.gz"

sudo su - yarn -c "gzip -d /mnt/var/log/tmp/var/log/hadoop-yarn/containers/application_1571216922451_0033/container_e26_1571216922451_0033_01_000004/stderr.gz"

#### EMR上SparkUIdriver里打印的ip:host不对

通过报错发现，ApplicationMaster对应的跳转链接为：http://ip1:4047，而airflow中显示的driver日志如下

INFO - Subtask: 19/10/31 08:49:39 INFO SparkUI: Bound SparkUI to 0.0.0.0, and started at ip1:4047

而通过Airflow调度执行的机器为 ip2，即spark-submit指定的机器IP为ip2,启动模式为yarn-client，所以SparkUI 的访问地址应该是ip2:4047
查看Spark源码可以发现，


查看/usr/lib/spark/conf/spark-env.sh可以看到，

EMR写死了PUBLIC_DNS,嗯, EMR 你真棒！

#### Spark application log 在本地的container-logs下没有

yarn开启了日志聚合，默认把日志聚合后，传到了hdfs上
https://www.jianshu.com/p/83fcf7478dd7
yarn logs -applicationId  可以看到所有的container日志
xxx -containerId xxxx // fail

sed -n '34826,44603p' container_xxx

#### SparkHistory看不到从Zeppelin提交的application

usermod -a -G examplegroup exampleusername
less /etc/groups
less /etc/passwd

### EMRFS

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


### 配置目录
cd /usr/lib/hadoop/etc/hadoop/

cd /etc/xxx/conf

EMR默认日志：/var/log/xxx
EMR默认配置:/etc/xxx/conf

### 命令

https://aws.amazon.com/cn/premiumsupport/knowledge-center/restart-service-emr/

sudo yarn rmadmin -refreshQueues
yarn application -kill application_1569748399237_0200

df -lh
sudo du -h --max-depth=1
sudo su - yarn -c "rm -rf /mnt/yarn/usercache"
df /var/log/hadoop-yarn/

/usr/lib/jvm/java-openjdk/bin/java -server -Xmx10240m -verbose:gc -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+UseConcMarkSweepGC -XX:CMSInitiatingOccupancyFraction=70 -XX:MaxHeapFreeRatio=70 -XX:+CMSClassUnloadingEnabled -XX:OnOutOfMemoryError=kill -9 %p -Djava.io.tmpdir=/mnt/yarn/usercache/hadoop/appcache/application_1569748399237_0491/container_1569748399237_0491_01_000356/tmp -Dspark.driver.port=46751 -Dspark.history.ui.port=18080 -Dspark.yarn.app.container.log.dir=/var/log/hadoop-yarn/containers/application_1569748399237_0491/container_1569748399237_0491_01_000356 org.apache.spark.executor.CoarseGrainedExecutorBackend --driver-url spark://CoarseGrainedScheduler@ip-172-31-20-22.us-west-2.compute.internal:46751 --executor-id 37 --hostname ip-172-31-19-184.us-west-2.compute.internal --cores 4 --app-id application_1569748399237_0491 --user-class-path file:/mnt/yarn/usercache/hadoop/appcache/application_1569748399237_0491/container_1569748399237_0491_01_000356/__app__.jar
