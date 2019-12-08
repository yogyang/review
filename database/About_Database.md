[TOC]

### Relational DB

#### 事务系列

https://v.youku.com/v_show/id_XODkwMzA1NDYw.html?spm=a2h0j.11185381.listitem_page1.5!5~A&&f=23339462



### NoSql

https://www.kdnuggets.com/2016/07/seven-steps-understanding-nosql-databases.html

https://www.youtube.com/watch?v=rnZmdmlR-2M

https://lagunita.stanford.edu/courses/DB/JSON/SelfPaced/courseware/ch-json_data/seq-vid-json_introduction/

#### KV Store



#### Document DB

MongoDB

https://docs.microsoft.com/en-us/archive/msdn-magazine/2011/november/data-points-what-the-heck-are-document-databases

 - Json Format - self describe 
```
The simplicity of JSON makes it easy to transpose object structures of almost any language into JSON. Therefore, you can define your objects in your application and store them directly in the database. This relieves developers of the need to use an object-relational mapper (ORM) to constantly translate between the database schema and the class/object schema.
```
数据存储格式为json,不需要像Relational Database一样，单独拎出来一个ORM层进行data->Specifc Class的转化.

Q： 那么，对于一个document db的开发者来说，开发者需要明确的知道数据的格式，即这个json里到底有哪些字段以及相应的含义。
- 对于业务开发者来说，业务逻辑是不是数据过于耦合？这到底是优点还是缺点？
- 无一致schema，数据差异性可以很大，业务是否会因为要处理各种case而强行写出了各种逻辑？

```
Databases don’t have to go trolling around to find data that’s commonly related, because it’s all together.
```
Q：No need to join any more。不存在传统关系型数据库中的范式设计原则，直接摒弃了join。

```
When interacting with the database, how does your application know that one item is a student, another is a book and another is a blog post? The databases use a concept of collections.
```
Q: 黑人 问号？？？ 啥意思

https://www.mongodb.com/document-databases

Document DB（No SQL ???）解决的问题
1.集群化，海量数据的可扩展性
2.schema-less，弱化结构，支持结构的可变性. -> 反范式，存储越来越便宜，空间换时间的思路。

#### Graph DB

Neo4j

Relational DB 关注于model逻辑之间的relationship，在传统关系型数据库下，要想发掘数据之间的关系，需要通过大量的表之join。
Graph Model关注于数据之间的relationship

##### 个人理解，may be wrong
Graph DB甚至于也支持ACID，图数据库更注重于数据之间的关系，它对数据的准确性和实时性也有一定的要求。
以一个图的逻辑概念去组织数据，感觉效率上会是一个很大的挑战，单条数据的操作，还是一些某些深度上的关系挖掘。
- 数据操作： 单条 / bulk
- 数据查询：
- 数据cluster: 图分区？ 

#### Time-Series DB
时序数据库

#### Search Engine


### Ranking
https://db-engines.com/en/ranking
原来hive算Relational.



### Format
#### Parquet

https://www.youtube.com/watch?v=1j8SdS7s_NY

- Hybird stroge : Row Group + Column Chunk
- RLE_DICTIONARY: 列值映射, value用数字(or others)代替(bit map), 连续重复的值压缩（1,1,2,2,2,3,3  ->  1,2  2,3 3,2）
- Dictionary , chunk metadate, footer metadata  ->  值， 最大最小等统计信息，支持部分查询的下推优化

![屏幕快照 2019-11-22 下午5.29.48](/Users/yoga/Documents/workspace/review/database/pic/屏幕快照 2019-11-22 下午5.29.48.png)

### 数据库的问题

计算 存储分离，Share noting/ Share everything
数据 schema分离
数据存储 和 索引存储



1. 存储方式 ->
    数据  列式/行式
    schema 结构化/非结构化 KV Json graph
    可扩展  分取
2. 查询 
   索引/KV
3. 

