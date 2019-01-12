- [ ] Multi SparkContext Demo

  - [ ] we want to have different configuration for different kind of jobs: 
    e.g.  spark.sql.shuffle.partitions=200 , big-data-job / 10, small-data-job 
  - [ ] http://livy.incubator.apache.org./
  - [ ]  does multi sparkSession can satisfy our need
  - [ ]  when to use which sparkcontext? how to manager? do we need share objects across the contexts?
- [ ] Spark Stage partitions merge
  - [ ] https://databricks.com/session/an-adaptive-execution-engine-for-apache-spark-sql
- [ ] https://www.snappydata.io/
- [ ] Datastax
- [ ] Parquet
- [ ] Transmitter Code Refactor
- [ ] Spark shuffle Read
- [ ] MTDI / Project schema 
  - [ ] SQL Generate
- [ ] scala constructer parameters: https://stackoverflow.com/questions/18623687/scala-constructor-parameters
- [ ] Personal
  - [ ] Hashshell : http://learnyouahaskell.com/chapters
  - [ ] Scala: https://www.scala-exercises.org/
- [ ] Dependency refactor
  - [ ] 1. EmmaRequst? why do we have subrequsts list? why do we have sqllist, it may have problem in SparkSQLloader
    2. Appscheme jdbcDataSender, 数据不会重复么
    3. Bde-model-simple datasourcestreaming不可以合在一起么
    4. 目前emmarequest里的inno-partiontion 这些概念有人用么
    5. 一些没有用的类现在是否可以删除？？
  - [ ] 互相依赖，导致build break
  - [ ] 



