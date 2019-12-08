[TOC]

#### Case4. 避免shuffle

同样是一条线上的SQL，组织类似

```
select a, sum(price), sum(arrive), sum(xxxx)
     select a, b, sum(price)
		  from
		   (
		   	select a, c, sum(d)
		   	from (
		   		select a,b,d
		   		from t1
		   		) t2 group by 1,2
		   ) t3 join dimensionT
		   on t3.c = dimensionT.c
	   group by 1,2
group by a
```

#### 分析
这条SQL很有意思，可以来详细分析以下。
1. select a,b,d from t1 as t2 没有什么搞头

2. select a,c,sum(d) from t2 group by 1,2 as t3  →  groupby  a,c 触发shuffle,数据按照(a,c)进行重分布

3. select a,b,sum(price) from t3 join dimensionT on t3.c = dimensionT.c  group by 1,2  as t4 

   join → 触发了一个sortmergeJoin, t3 数据按照c重分布，dimensionT表的数据按照c重分布，两个shuffle   

  group by 1,2 →  join出来的宽表， join完成后数据是按照c进行分区的， group by要求按照a,b重分布 →  触发shuffle

4. select a , sum(price),  sum(arrive) from t4 group by a →  数据目前按照a,b分区，group by要求按照a进行重复 → 按我的理解这应该是个窄依赖，但是从试验看来，依旧触发了shuffle，嗯。。。我也很迷

对应的执行stage图如：

![ case4_1](https://raw.githubusercontent.com/fuqiliang/review/master/big-data/spark/Spark任务优化/pic/%20case4_1.png)



#### 思路

那么这条我们优化的思路如下：

1. join对应的SparkUI数据对比如下：

   ![case4_2](https://raw.githubusercontent.com/fuqiliang/review/master/big-data/spark/Spark任务优化/pic/case4_2.png)

   从图可以看到143.4G join 一个170M的表，按照大表join小表的优化思路，可以将小表进行广播，避免join触发的这两次shuffle.

2.   当我们避免了t3数据按照c重分布之后，我们可以来理一下源数据的重分布路线

   ![case4_3](<https://raw.githubusercontent.com/fuqiliang/review/master/big-data/spark/Spark任务优化/pic/case4_3.png>)

  这种情况下, 每次的重分布都是一次宽依赖，需要进行shuffle。
  而这三次的数据重新分布都是以a开始，那么如果一开始就将源数据以a进行数据repartition，那么这三次宽依赖是否都可以变成窄依赖？

#### 尝试
按照上面的思路，我们重写了一下SQL，提交执行
新的stage图：
中间所有的shuffle过程消失了！
![case4_4](<https://raw.githubusercontent.com/fuqiliang/review/master/big-data/spark/Spark任务优化/pic/case4_4.png>)
Join也变成了BroadcastJoin。

然而，这个SQL的执行时间并没有减少，可能还是数据量太小了吧。

不过这个case是个我个人做的很开心的一个尝试，因为感觉简直就是教科书一般的尝试 。

这个case又引出了另外一个问题，真实的线上代码是这条SQL同样的模式下运行了6遍，有一些公用的中间SQL，我尝试了把SQL分解，中间RDD（也就是stage8的输出）进行cache,确实后续5遍的SQL执行时间变快了，但是缓存的RDD有一个奇怪的地方：

Q： RDD1 -> RDD2, 缓存RDD2，RDD1的shuffle write 20G,但是缓存的大小大概能到40-60G。由于cache的数据的极具增大，反而导致后续读cache的Job执行很容易OOM，导致task重试，执行时间反而变慢了。