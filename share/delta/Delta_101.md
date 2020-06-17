---
marp: true
# theme: uncover
# _class: invert

---

### Before Delta

Your dataset using format `parquet`

Delete Customer with Cid = 250

---

### Before Delta

Steps:
1. find your target partition if you have one, overwrite that partition

![parquet_update](https://raw.githubusercontent.com/yogyang/review/master/share/delta/pics/parquet_update.jpg)


Problem:
1. what if failure on parquet_f3 -> You may loss your other 200-300 customers
2. What if others need to read cid > 250 -> Fail Or Blocked

---

### After Delta
1. deltaTable.delete($"cid" === "250")

![delta_update](https://raw.githubusercontent.com/yogyang/review/master/share/delta/pics/parquet_update.jpg)

Pros:
1. ACID contril on your delete action -> ACID
2. Downstream can still Read on V1 -> TimeTravel

---

### What's in Delta

1. ACID
2. Delta Log
3. Time Travel
4. Schema change
5. Delta as Streaming Source

---

### ACID

What happened when `overwrite` on `parquet`

> Delete (Mark or Real)
> Write

Atomic? -> Consistency? -> Isolation? -> Durable?

No transcation at all in Spark alone.

But S3?

---

### ACID

Senarios of ACID requirements

1. COMPRESSION: too many small files, two large file numbers are slowing down your query
2. UPDATE/DELTE/MERGE: what if you have some broken data? stop all your downstreams' read? 

---

### How ACID in Delta

```
 df.write
      .format("delta")
      .mode(SaveMode.Overwrite)
      .partitionBy("p")
      .save(s"test_$formatM")
```

Codes Internal:

```
deltaLog.withNewTransaction { txn =>
      val actions = write(txn, sparkSession)
      val operation = DeltaOperations.Write(mode, Option(partitionColumns), options.replaceWhere)
      txn.commit(actions, operation)
    }
``` 

---

### [Delta Log](https://github.com/delta-io/delta/blob/master/src/main/scala/org/apache/spark/sql/delta/DeltaLog.scala)

- Delta logs is the only truth of what the data is, including raw data, partition, schema
- Append-only logs, each operation you executed will create a new version log, reflecting your incremental change



---

### Delta log

![delta_log_structure](https://raw.githubusercontent.com/yogyang/review/master/share/delta/pics/delta_log_formats.jpg)


---

### Delta log

**Format:**
- json
- checkpoint.parquet
- last_checkpoint

> Data File Indexes + Schema = v1.json + v2.json + ... + Vn.json

OR

> Data File Indexes + Schema = Vx.checkpoint.parquet + Vx+1.json + Vx+2.json + ...

---

### Delta Log

![delta_log_contents](https://raw.githubusercontent.com/yogyang/review/master/share/delta/pics/delta_log_contents.jpg)

**Contents:**
- commitInfo : `DESCRIBE HISTORY` 

- protocol
- metaData: schema, table-level-config, ..
- actions: AddFile, RemoveFile


---

### Transcation

Any thing wrapped in
```
deltaLog.withNewTransaction {
   trx => xxxx
}
```

Conflict Control:
https://docs.databricks.com/delta/concurrency-control.html

Codes:
[DoCommit](https://github.com/delta-io/delta/blob/dc20a2739c19744e91d9047228af584c7ce73993/src/main/scala/org/apache/spark/sql/delta/OptimisticTransaction.scala#L407)



---

### Time Travel

```
 val deltaLog = DeltaLog.forTable(sqlContext.sparkSession, path)
```

```
deltaLog.getSnapshotAt(1990)
```

Main logic is:
* Combining different delta_logs 
* You can only travel back the your oldest delta log checkpoint

V4 = V0.json+ V1.json + V2.json + V3.json + V4.json
V2 = V0.json+ V1.json + V2.json

--- 

### Schema Change

https://docs.databricks.com/delta/delta-batch.html#schema-validation-1

[Codes](https://github.com/delta-io/delta/blob/dc20a2739c19744e91d9047228af584c7ce73993/src/main/scala/org/apache/spark/sql/delta/schema/ImplicitMetadataOperation.scala#L50)

- current: DataType (From transction snapshot), update: DataType (data Your wrote)
- conversion on read

---

### Data Change

* API Support: Update/Merge/Delete

* Change on Write, Comparing to Hudi, merge on Read, write on Avro


---

### Datalake Comparison

![comparison](https://raw.githubusercontent.com/yogyang/review/master/share/delta/pics/datalake_compare.jpg)

---

### [Delta as Streaming Source](https://github.com/delta-io/delta/tree/master/src/main/scala/org/apache/spark/sql/delta/sources)

![streaming_checkpoint](https://raw.githubusercontent.com/yogyang/review/master/share/delta/pics/streaming_checkpoint.jpg)

**Key Point Here: OffSets**
- KafaOffset:
![kafka_offset](https://raw.githubusercontent.com/yogyang/review/master/share/delta/pics/kafka_offset.jpg)


- DeltaSourceOffset
![versions](https://raw.githubusercontent.com/yogyang/review/master/share/delta/pics/delta_offset.jpg)
   
---

### Delta As Streaming source

- DeltaSourceOffset:
 > reservoirVersion: The version of the table that we are current processing.
index: The index in the sequence of AddFiles in this version. 

- GetBatch: [GetBatch](https://github.com/delta-io/delta/blob/dc20a2739c19744e91d9047228af584c7ce73993/src/main/scala/org/apache/spark/sql/delta/sources/DeltaSource.scala#L269)
  
   - Only AddFiles & isDataChange=true are passed
   - Overwrite/Update/Delete on-no-partition will genereate AddFile too

**All is based on DeltaLog**
**But still be carefull on deduplicate**

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























