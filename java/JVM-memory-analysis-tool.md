### JVM 内存分析Tools

今天工作需要测试一段代码是否有效执行了对象的回收，期间使用了java内存分析工具等，总结知识点。

> * jmap
> * jstat
> * jhat
> * mat
> * java 内存模型
> * java GC

---
## Jmap
生成堆快照
> * jmap -heap :当前堆内存分布信息，如From space, To Space等占用内存大小
> * jmap -histo : 当前堆中对象占用内存大小情况，柱状图数据结构组织。可以简单得定位下当前占用内存最大的几个对象
> * jmap -histo:live:先触发一次gc , 再统计对象占用内存情况。可以简单得定位下当前占用内存最大的几个对象以及对象是否可以被gc回收
> * jmap -dump:format=b,file=heapDump: 导出堆详细使用信息，b表示二进制文件，之后采用其他工具分析，如jhat,mat.非常详细，可分析到对象之间的引用关系等。

 ## Jstat
显示进程中的类装载、内存、垃圾收集、JIT编译等运行数据
目前感觉用上的都是gc记录查看，实际还没太用过
> * jstat -gc 3331 250 20: 查询进程2764的垃圾收集情况，每250毫秒查询一次，一共查询20次。
> * jstat- gcause

##Jhat
可用来分析 jmap dump生成的堆信息二进制文件。html形式显示对象占用内存大小以及引用情况，但显示得并不友好。感觉比较鸡肋。
> * jhat file

## mat
eclipse提供的jvm 内存分析工具，图形化界面，很好用。 可分析引用（出度，入度），引用的内容等，强烈推荐，idea不带这种插件，可以单独下。如果要分析的堆文件太大，可能oom，需要修改MemoryAnalyzer.ini 里启动的jvm参数。

## java 内存模型
如图

![内存模型.png](http://upload-images.jianshu.io/upload_images/4849306-f6a606caefa96cf0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

至于oom以及相应的jvm参数，还有很多细节。Jdk 1.8中已经删除了perSize相关参数。oom什么情况下会产生，跟gc的方式也相关。后续继续。

## java GC
在oom试验中，设置了perSize＝10m maxPerSize=10m ，通过string.intern循环产生string常量，却一直没有perm gen oom.查看jmap -heap ，发现内存中ps old gen 已经600M+, per gen 2m+.为什么？