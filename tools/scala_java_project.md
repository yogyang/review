1.create the project from scala-archetype-simple

两种方式
> 1. mvn 命令： mvn archetype:generate \
>   -DarchetypeGroupId=org.scala-tools.archetypes \
>   -DarchetypeArtifactId=scala-archetype-simple \
>   -DremoteRepositories=http://scala-tools.org/repo-releases
> 2. idea -> create project -> create from archetype -> select scala-archetype-simple

2.手动创建java src 目录

3.修改pom
 > 3.1. 删除
 ```
  <sourceDirectory>src/main/scala</sourceDirectory>
<testSourceDirectory>src/test/scala</testSourceDirectory>
 ```
> 3.2. 添加
```
<plugin>
<groupId>org.codehaus.mojo </groupId>
<artifactId>build-helper-maven-plugin </artifactId>
<version>1.9.1 </version>
</plugin>
```
>3.3 mark java src as src dir