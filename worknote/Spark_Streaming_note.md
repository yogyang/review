https://jaceklaskowski.gitbooks.io/spark-structured-streaming/spark-structured-streaming.html

https://docs.databricks.com/spark/latest/structured-streaming/index.html

>Structured Streaming queries are processed using a *micro-batch processing* engine, which processes data streams as a series of small batch jobs thereby achieving end-to-end latencies as low as **100 milliseconds** and  **exactly-once** fault-tolerance guarantees.

>**Continuous Processing**, which can achieve end-to-end latencies as low as **1 millisecond** with **at-least-once** guarantees. 



> Every **trigger interval** (say, every 1 second), new rows get appended to the Input Table,

> **watermarking** : This means the system needs to know when an old aggregate can be dropped from the in-memory state because the application is not going to receive late data for that aggregate any more.



#### Update Mode VS Append Mode

相当详细

Update Mode: 每个trigger点都会把当前各个有效窗口的更新的数据写入sink

Append Mode:只有当window 正式retire的时候，才将数据写入sink ,注意retire的条件：hen drops intermediate state of a window < watermark，**小于小于小于**而不是小于等于

https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html

##### Conditions for watermarking to clean aggregation state

It is important to note that the following conditions must be satisfied for the watermarking to clean the state in aggregation queries *(as of Spark 2.1.1, subject to change in the future)*.

- **Output mode must be Append or Update.** Complete mode requires all aggregate data to be preserved, and hence cannot use watermarking to drop intermediate state. See the [Output Modes](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html#output-modes) section for detailed explanation of the semantics of each output mode.
- The aggregation must have either the event-time column, or a `window` on the event-time column.
- `withWatermark` must be called on the same column as the timestamp column used in the aggregate. For example, `df.withWatermark("time", "1 min").groupBy("time2").count()` is invalid in Append output mode, as watermark is defined on a different column from the aggregation column.
- `withWatermark` must be called before the aggregation for the watermark details to be used. For example, `df.groupBy("time").count().withWatermark("time", "1 min")` is invalid in Append output mode.

#### GroupState

```
 For a streaming
* Dataset, the function will be invoked for each group repeatedly in every trigger.
```

