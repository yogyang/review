[TOC]



## How to Understand SBT

### What is a SBT

```
 The interactive build tool
 Define your tasks in Scala. Run them in parallel from sbt's interactive shell. 
```

提取一下关键字

1. build tool  :  like maven, ant, make, rake等，可以帮助开发者方便地进行依赖管理、项目的各种构建需求（compile, test, package）
2. interactive : like bash, 可交互的。不像man
3. define tasks:   这一点是理解sbt的关键，sbt实际上可以看成一个任务执行引擎，用户通过.sbt以及.scala文件来对task进行定义、描述、组织。而 sbt负责解析这些所有 task的依赖关系，自动完成task->子task的拆分以及执行。
4. parallel：这是sbt跟其他build tool的一个比较大的区别，至少官网上是列为一个highlight feature的。上面说了，sbt实际上是负责了task->子task的拆分，那么如果一个task包含多个子task,sbt 是支持不相关的子task并行的。

### Sample usage

首先我们有一个如下结构的项目：

![image-20190116220250272](/Users/yoga/Library/Application Support/typora-user-images/image-20190116220250272.png)

通过对sbt简单的语法学习，我们任务这个scala项目，是一个multi project 的项目，有项目subModule(默认根项目), ma, mb



那么，你如何确认sbt 确实是按照你的想法去解析这个项目的呢？

换个说法，当你把build.sbt写完后，你如何进行验证？

#### Interactive

这个时候就应该使用sbt interactive的特性，

console-> 进入项目地址 -> sbt 

 #####  projects

```
 ~/Documents/workspace/subModule   master ●✚  sbt
[info] Loading project definition from /Users/yoga/Documents/workspace/subModule/project
[info] Loading settings for project submodule from build.sbt ...
this is in settingSample, should be executed once when session starts
[info] Set current project to subModule (in build file:/Users/yoga/Documents/workspace/subModule/)
[info] sbt server started at local:///Users/yoga/.sbt/1.0/server/d809cc5f6cbf82c87896/sock
sbt:subModule> projects
[info] In file:/Users/yoga/Documents/workspace/subModule/
[info] 	   ma
[info] 	   mb
[info] 	 * submodule
```

通过sbt的输出，你可以看出当前生效的配置为build.sbt

```projects```命令，可以展示当前生效的项目分别是哪些，且目前工作在哪个project下（* submodule）

##### project

同时，你也可以通过```project```来切换工作project，比如你希望只跑ma下的test

```
project ma
test
```

 ##### reload

另外一个很有用的命令是```reload```, 这个命令可以重新加载当前project的配置，比方说你对build.sbt 做了修改，在sbt  session下可以通过执行reload 直接对配置进行刷新。对于我这种写sbt60%靠猜的人来说，十分有用！！

compile



What is behind the Task



### How to write

#### sbt is a DSL

Sample



