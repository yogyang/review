### About SBT

[TOC]

#### Some Command

sbt "testOnly testA"

sbt xxx/package 

sbt xxx/makePom 

sbt packageSrc



#### Write a SBT Plugin and Publish

<https://codewithstyle.info/how-to-build-a-simple-sbt-plugin/> <https://central.sonatype.org/pages/ossrh-guide.html>

sbt publishLocal

sbt publish

export GPG_TTY=$(tty)

sbt publishSigned

 [https://oss.sonatype.org](https://oss.sonatype.org/)

<https://issues.sonatype.org/browse/OSSRH-44290>

[http://www.spoofer.top/2016/03/21/使用sbt插件上传scala项目lib到Maven仓库](http://www.spoofer.top/2016/03/21/%E4%BD%BF%E7%94%A8sbt%E6%8F%92%E4%BB%B6%E4%B8%8A%E4%BC%A0scala%E9%A1%B9%E7%9B%AElib%E5%88%B0Maven%E4%BB%93%E5%BA%93)



#### Check Dependency

[sbt-dependency-tree](https://github.com/jrudolph/sbt-dependency-graph)

sbt dependencyTree

sbt -> plugins projects





