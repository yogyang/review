[TOC]

###  Java Classloader ClassInitialization InstanceInitialization

---

说到Java的类加载，书本(深入理解Java虚拟机)或者其他[参考](http://www.cubrid.org/blog/dev-platform/understanding-jvm-internals)，我们都能知道，Java类加载的过程是分为如下图所示：

![classloader stage](/Users/yujyang/Documents/workspace/review/java/pictures/classloader%20stage.png)

那么问题来了

定义Person类如下，有一个static 变量，以及static  code  block.

以及其子类Student

```java
public class Person {
    public static String s = "Person"; // static value

    static {  //static block
        System.out.println("Person: This should be executed when initializing");
    }

    {  
        System.out.println("Person: This should be executed after static when initializing");
    }


    private String name;

    public Person(){
    }

}
```

```java
public class Student extends Person {

    static {
        System.out.println("Student: This should be executed when initializing");
    }

    {
        System.out.println("Student: This should be executed after static when initializing");
    }
}
```



#### Q1

 当main函数如下调用时候，到底输出什么

 ```java
public static void main(String... args) throws InterruptedException {
        String s = Student.s;
    }
 ```

要回答这个问题，我们首先要有一下认知

1. 类加载的过程：Loading -> Verifying -> Preparing -> Resolving ->Initializing
2. 具体细化来说，一个类从加载到完成**实例初始化**: static value -> static block -> common value -> common block -> constructer
3. 再牵扯进父子类，子类加载会引发父类的加载，具体执行上也是2的基础上保持静态先执行。

回到类加载分析，读取Student.s ，到底出发了些什么？

1. 首先引用了Student.class -> Student.class 加载，也就是Student.class Loading 

2. Student.class Loading -> Person.class Loading

3. 访问Person类的静态变量s -> 对Person.class进行getstatic -> Person.class的Initializing类初始化

而在完成某个类初始化之前，JVM会执行类的<clinit>，<clinit>即是执行当前类的所有静态变量以及静态code的处理。
那么，至此我们可以分析出 输出台应该输出

```java
"Person: This should be executed when initializing"
```

我们实际跑一下，为了方便看类加载的信息，加上-verbose

![image-20190113001429978](/Users/yujyang/Library/Application Support/typora-user-images/image-20190113001429978.png)

这个问题说明了什么呢？

1.  类被ClassLoader读取后，即只是Loading完成时候，其实JVM并没有实际执行该class中任何字节码，仅仅是Loading

2. 类初始化和实例初始化的区别：我们通过说先 static -> common -> constructe的这个流程，实际上对应的是一个完成的 new Person()即实例初始化过程。也就是JVM cinit() -> init的过程

3. 本例中，当执行Student.s时候，出发了Person 的类初始化过程，即cinit -> Person static code的执行

4. 本例中，并没有执行new Person()的操作，也就并没有实例初始化过程，即未出发common code block的执行等

   
#### Reference

http://www.cubrid.org/blog/dev-platform/understanding-jvm-internals

https://www.cnblogs.com/ssslinppp/p/6478820.html

