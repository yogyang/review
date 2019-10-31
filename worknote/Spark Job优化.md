####Spark Job优化

1.  去除show (). count

2. 重用计算结果

   ```scala
   for(i <- 0 to cols.length-1){
         df = df.withColumn(cols(i),split($"value","\\|")(i))
       }
   ```

   换成

   ```scala
   val df2 = df.select(cols.indices.map(i => col("value")(i).alias(cols(i))) : _*)
   ```

   

