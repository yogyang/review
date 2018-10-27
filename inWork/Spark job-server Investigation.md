##Multi-SparkContext Investigation

[TOC]

### spark-jobserver



1. Scala-version mismatch : https://github.com/spark-jobserver/spark-jobserver/issues/1074

2. multi sparkcontext : https://issues.apache.org/jira/browse/SPARK-2243



### Livy

http://livy.incubator.apache.org./

https://github.com/jupyter-incubator/sparkmagic

Yarn-client vs. yarn-cluster : https://www.iteblog.com/archives/1223.html



### FAQ

1. Difference between spark-jobserver & livy
2. 每个context的启动是否会有很大延迟
3. context的回收
4.  Sql-> context的映射关系/分配策略
5. SparkSession到底有没有用



