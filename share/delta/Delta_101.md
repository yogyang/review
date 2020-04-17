---
marp: true
# theme: uncover
# _class: invert
---

### Contents

1. ACID
2. Delta Log
3. Time Travel
4. Schema change / Data Incremental Change
5. Delta as Streaming Source


---

### ACID

`overwrite` on `parquet`

> Delete (Mark or Real)
> Write

Atomic? -> Consistency? -> Isolation? -> Durable?

No transcation at all in Spark alone.

But S3?

---

### ACID

1. COMPRESSION
2. UPDATE/DELTE/MERGE

---

### How ACID in Delta

```
 df.write
      .format("delta")
      .mode(SaveMode.Overwrite)
      .partitionBy("p")
      .save(s"test_$formatM")
```
Internal:

> DeltaDataSource
-> Sink
-> RelationProvider :
     WriteIntoDeltaCommand ->  deltaLog.withNewTranscation 
     -> execute action  -> commit 

---

### Delta Log

[Source Code](https://github.com/delta-io/delta/blob/master/src/main/scala/org/apache/spark/sql/delta/DeltaLog.scala)

![delta_log](/Users/yoga/Desktop/delta_log.jpg)
- metadata
- AddFile
- RemoveFile

- json
- checkpoint.parquet

---

### Transcation Do Commit

[DoCommit](https://github.com/delta-io/delta/blob/dc20a2739c19744e91d9047228af584c7ce73993/src/main/scala/org/apache/spark/sql/delta/OptimisticTransaction.scala#L407)

What is a Transcation?
- DeltaCommand
- DataFrame API

---

![delta_dataset](/Users/yoga/Desktop/delta_dataset.jpg)

---

### Time Travel

```
 val deltaLog = DeltaLog.forTable(sqlContext.sparkSession, path)
```

```
deltaLog.getSnapshotAt(1990)
```

* delta_logs 
![versions](/Users/yoga/Desktop/versions.jpg)

Current Snapshot -> Gather Latest Versions -> Valid Files

--- 

### Schema Change

[Codes](https://github.com/delta-io/delta/blob/dc20a2739c19744e91d9047228af584c7ce73993/src/main/scala/org/apache/spark/sql/delta/schema/ImplicitMetadataOperation.scala#L50)

- current: DataType (From transction snashot), update: DataType (Your wrote data)
- conversion on read

---

### Data Change

* GDPR

Update/Merge/Delete

* Change on Write

Compared to Hudi

* Change on Read, Write on Avro

---

### Datalake Comparison

![versions](/Users/yoga/Desktop/data_lake.jpg)

---

### Delta as Streaming Source

[Related Codes](https://github.com/delta-io/delta/tree/master/src/main/scala/org/apache/spark/sql/delta/sources)

- GetBatch: [GetBatch](https://github.com/delta-io/delta/blob/dc20a2739c19744e91d9047228af584c7ce73993/src/main/scala/org/apache/spark/sql/delta/sources/DeltaSource.scala#L269)
  
   - Only AddFiles & isDataChange=true are passed

- DeltaSourceOffset
![versions](/Users/yoga/Desktop/delta_offset.jpg)

All is DeltaLog

But still be carefull on deduplicate

---

**Q1: the problems delta solved, and how**
 a. ACID -> deltalog
 b. schema/data change 
    - prediction overwride
    - filter push down
 c. Some kind of batch/streaming unified API
    https://eng.uber.com/kappa-architecture-data-stream-processing/
 d. Audit Log
 e. auto optmize -> Problems on how the optimize write
 f. more effiency on read -> need compare, and reserach


---
**Q2:efficiency on time-travel and write(compared to parquet append)**
a. Time-travle: get snapshot before read
b. 
  - write: append/overwrite -> extra effort on delta_log
  - update/delte on proiton: Query Optimization
    - Partiton
    - Data Skip
   > Finding files for Rewrite delte
   Rewriting 29 files for DELETE operation / 100
 
 ---
 
 Related Post:
 1. https://www.youtube.com/watch?v=0GhFAzN4qs4
 2. https://eng.uber.com/kappa-architecture-data-stream-processing/
 3. https://www.reddit.com/r/dataengineering/comments/dr2rni/databricks_delta_apache_hudi_and_apache_iceberg/























