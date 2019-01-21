title: Quick Understanding of SBT
author:
  name: Yujia Yang
  url: http://jordanscales.com
output: index.html
controls: true

--

### Quick Start of SBT

<code>The <strong> interactive</strong> build tool</code>

<code> <strong>Define</strong> your tasks in Scala</code>

<code>Run them in <strong>parallel</strong> from sbt's interactive shell </code>

--

### Interactive Sample

 - projects / project

 - reload

 - inspect / inspect tree

 - < task > / show < task >

 - testOnly / testQuick

[Command line Reference](https://www.scala-sbt.org/1.x/docs/Command-Line-Reference.html)

--

### Batch Mode

```
$ sbt clean compile "testOnly TestA TestB"
```

![batch_mode]{https://raw.githubusercontent.com/fuqiliang/review/master/share/sbt/pics/batchMode.png}



--

### Task Engine - Task

#####  The common commands you can run are almost all tasks!

compile  , test ,  sources ……   

![inspect_source](https://raw.githubusercontent.com/fuqiliang/review/master/share/sbt/pics/inspect_source.png)



--

### Task Engine -Setting

#####  The common commands you can run are almost all tasks!

name, scalaSource, javaSource ....

![inspect_name](https://raw.githubusercontent.com/fuqiliang/review/master/share/sbt/pics/inspect_name.png)



--

 ### TaskEngine - Setting VS Task

* Settings are evaluated at project load time
* Tasks are executed on demand, often in response to a command from the user
* Settings can only depend on Settings
* Tasks can depend on Settings and Tasks

##### Depend

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

![inspect_tree_source](https://raw.githubusercontent.com/fuqiliang/review/master/share/sbt/pics/inspect_tree_source.jpg)



--

### TaskEngine - DAG

Inspect tree sources -> Change a view to see

![dag](https://raw.githubusercontent.com/fuqiliang/review/master/share/sbt/pics/dag.jpg)



--

### TaksEngine - Scope

a full scope in sbt is formed by a **tuple** of a subproject, a configuration, and a task value:

```scala
Provided by:
ProjectRef(uri("file:/Users/yoga/Documents/workspace/subModule/"), "submodule") /
Compile /
sources
```



```scala
projA / Compile / console / scalacOptions
```



<i>Usage : you want different task result in different configuration, e.g different source files for Compile and Test</i>

<i> Look up:  Delegates</i>



--

### TaksEngine - Scope

Let's define a task / setting of ourselves

```scala
//define a task Key
val taskSample = taskKey[String]("task sample")
// give the task an implemention, we can call it an entry for the key
taskSample := {
  println("this in taskSample, can be executed multiple times")
  "Content for TaskSample"
}

// define a setting Key
val settingSample = settingKey[String]("setting sample")
// give the task an implemention
settingSample := {
  println("this is in settingSample, should be executed once when session starts")
  "Content for SettingSample"
}
```



--

### TaksEngine - Scope

Let's implement another task with name "**taskSample**" but **in different scope**

```scala
ThisBuild / settingSample := "ThisBuild: Content for SettingSample"

val ma = (project in file("Ma")).settings(
  scalaSource in Compile := baseDirectory.value / "src",
  javaSource in Compile := (scalaSource in Compile).value,
  taskSample in Compile := {
    println("MA: this in taskSample, can be executed multiple times")
    "MA: Content for TaskSample"
  },
  name := "MA"
)

val mb = (project in file("Mb")).settings(
  scalaSource in Compile := baseDirectory.value / "src",
  javaSource in Compile := (scalaSource in Compile).value,
  settingSample in Compile := {
    println("MB: this is in settingSample, should be executed once when session starts")
    "MB: Content for SettingSample"
  },
  name := "MB"
)
```



--

### SBT- DSL

**It's not just  Scala! It's built on Scala.**   

[Three things I had to learn about Scala before it made sense](https://jazzy.id.au/2012/03/19/three_things_i_had_to_learn_about_scala_before_it_made_sense.html)

How do we define dependencies in mvn?

```mvn
<dependency>
    <groupId>net.vz.mongodb.jackson</groupId>
    <artifactId>mongo-jackson-mapper</artifactId>
    <version>1.4.1</version>
</dependency>
```



-- 

### SBT- DSL

How can we describe a dependency in a scala way?

```scala
def groupId(groupId: String) = new GroupId(groupId)

class GroupId(val groupId: String) {
  def artifact(artifactId: String) = new Artifact(groupId, artifactId)
}

class Artifact(val groupId: String, val artifactId: String) {
  def version(version: String) = new VersionedArtifact(groupId, artifactId, version)
}

class VersionedArtifact(val groupId: String, val artifactId: String, val version: String) {
}
```

Then we got

```scala
groupId("net.vz.mongodb.jackson")
    .artifact("mongo-jackson-mapper")
    .version("1.4.1")
```



--

### SBT- DSL

Scala methods can be made of **operator characters**

```scala
def groupId(groupId: String) = new GroupId(groupId)

class GroupId(val groupId: String) {
  def %(artifactId: String) = new Artifact(groupId, artifactId)
}

class Artifact(val groupId: String, val artifactId: String) {
  def %(version: String) = new VersionedArtifact(groupId, artifactId, version)
}
class VersionedArtifact(val groupId: String, val artifactId: String, val version: String) {}
```
Then
```scala
groupId("net.vz.mongodb.jackson").%("mongo-jackson-mapper").%("1.4.1")
```

Omit the `.`

```scala
groupId("net.vz.mongodb.jackson") % ("mongo-jackson-mapper") % ("1.4.1")
```

--

### SBT- DSL

Scala lets you **implicitly** **convert** any type to any other type

```scala
implicit def groupId(groupId: String) = new GroupId(groupId)
```

Then when we write down below

```scala
"net.vz.mongodb.jackson" % "mongo-jackson-mapper" % "1.4.1"
```

It's equal to 

```scala
"net.vz.mongodb.jackson".artifact("mongo-jackson-mapper").version("1.4.1")
```



-- 

### SBT- DSL 

 **implicitly convert**

```scala
"net.vz.mongodb.jackson".artifact("mongo-jackson-mapper").version("1.4.1")
```

![inspect_source](https://raw.githubusercontent.com/fuqiliang/review/master/share/sbt/pics/scala_implicitly.png)



```scala
groupId("net.vz.mongodb.jackson").artifact("mongo-jackson-mapper").version("1.4.1")
```



--

### SBT- DSL 

Theres are all **functions**  with  return type are **Def.Setting[T]**  or **Seq[Def.Setting[T]]**

:=   ++   ++=   in 

Belows are **expressions**! Not **statements**!

```scala
name := "subModule"
```

This is equal to 

```scala
name.setEntry("subModule")
```

--

### SBT- DSL 

```scala
name := "subModule"
```

1. name is an instance of Type **SettingKey**

2. calls the **function :=**

3. with **String parameter** "submodule"

4. returns a **Setting**




**Q: Look back on the build.sbt, try to explain what happened for the build.sbt you defined?**

```
//this is a expression!! not a statement
//this := returns Setting[Task], and the return setting is added into the project's setting list !!!!
//OH MY GOD!!!!ddddddddddddde
```



--

### SBT-Project

![project-settings](https://raw.githubusercontent.com/fuqiliang/review/master/share/sbt/pics/project-settings.jpg)

--

### SBT- User Defined

**Project is defined by multiple Def.Settings, this settings defined** 

```
1. what tasks(including setting-task) do we support in this project
2. what's unique name for the tasks - the scopes
3. what's the dependencies between the tasks
4. how will the tasks be implemented
```

 **Statement VS Expression**

```
val settingSample 
```

```
:= ++ ++= ...
should return  Def.Setting[T] or Seq[Def.Setting[T]]
```

--

### Aggerate VS Depend

aggregate:

* trigger all the tasks of the project you aggregate with

depend:

* trigger the compile of the project you depend on
* add the compile classes to your class path

--

### Why does it fail? How to fix?

 In Project/CustomeSettings.scala

```scala
import sbt.{Setting, taskKey, settingKey}

object CustomeSettings {

  lazy val currentOs = settingKey[String]("The version of Scala used for building.")

  //choose the protobuf path according to the os
  lazy val printCurrentOS = taskKey[String]("print the current os type")

  currentOs := sys.props("os.name")

  printCurrentOS := {
    val os = currentOs.value
    println(s"current build on os:${os}")
    os
  }

}
```










