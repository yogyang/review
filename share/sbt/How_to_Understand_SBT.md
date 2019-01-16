title: Quick Understanding of SBT
author:
  name: Yujia Yang
  url: http://jordanscales.com
output: basic.html
controls: true

--

# Quick Start of SBT


--

### Interactive Sample

 * projects
 * project
 * reload
 * inspect
 * inspect tree
 * < task > 
 * show < task >

--

### Task Engine - Task

#####  The commands you can run are all tasks!

compile  , test ,  sources ……   

![inspect_source](/Users/yoga/Documents/workspace/review/share/sbt/pics/inspect_source.png)



--

### Task Engine -Setting

The commands you can run are all tasks!

name, scalaSource, javaSource ....

![inspect_name](/Users/yoga/Documents/workspace/review/share/sbt/pics/inspect_name.png)



--

 ### TaskEngine - Setting VS Task

* Settings are evaluated at project load time
* Tasks are executed on demand, often in response to a command from the user
* Settings can only depend on Settings
* Tasks can depend on Settings and Tasks

#### Depend

**.value**

```scala
 scalaSource in Compile := baseDirectory.value / "src",
 javaSource in Compile := (scalaSource in Compile).value,
```



 [Tasks](https://www.scala-sbt.org/1.x/docs/Tasks.html)

[Tasks/Settins](https://www.scala-sbt.org/1.x/docs/Task-Inputs.html)



--

### TaskEngine - DAG

Inspect tree sources

![inspect_tree_source](/Users/yoga/Documents/workspace/review/share/sbt/pics/inspect_tree_source.jpg)



--

### TaskEngine - DAG

Inspect tree sources -> Change a view to see

![dag](/Users/yoga/Documents/workspace/review/share/sbt/pics/dag.jpg)



--

### TaksEngine - Scope

a full scope in sbt is formed by a **tuple** of a subproject, a configuration, and a task value:

```scala
Provided by:
[info] 	ProjectRef(uri("file:/Users/yoga/Documents/workspace/subModule/"), "submodule") / Compile / sources
```



```scala
projA / Compile / console / scalacOptions
```



* Usage : you want different task result in different configuration, e.g different source files for Compile and Test
* Look up:  **Delegates**

--

### TaksEngine - Custome Task

```scala
val taskSample = taskKey[String]("task sample")
//this is a expression!! not a statement
//this := returns Setting[Task], and a setting in the project settingLIST !!!!
//OH MY GOD!!!!ddddddddddddde
taskSample := {
  println("this in taskSample, can be executed multiple times")
  "Content for TaskSample"
}

val settingSample = settingKey[String]("setting sample")
settingSample := {
  println("this is in settingSample, should be executed once when session starts")
  "Content for SettingSample"
}


```

