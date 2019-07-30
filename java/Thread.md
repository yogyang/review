### Thread

#### Blogs

[http://intheworld.win/2017/07/08/jvm%E5%8E%9F%E7%90%86%E4%B8%8E%E5%AE%9E%E7%8E%B0-thread/](http://intheworld.win/2017/07/08/jvm原理与实现-thread/)

<https://www.usenix.org/legacy/event/jvm01/full_papers/dice/dice.pdf>

<https://juejin.im/post/5abc9de851882555770c8c72>

<https://www.jianshu.com/p/f4454164c017>



#### Contents

很早之前看了一点，现在再看一遍，理一下synchronize，不确定。

1.synchronize 的两种使用方式Class类对象上锁控制，类实例对象上的锁控制。

2.每个Java对象都是一把锁 一个monitor 

3.Java 对象头里存在的MarkWord 在加锁状态下某几个bit值称为lockword , 指向monitor地址（ObjectMonitor?）, 这个monitor在JVM中实现为C++的ObjectMonitor. 其中封装了这个一个锁的状态：当前持锁线程，blockSet(申请持锁但锁已被其他线程持有，进入block状态), waitingSet(持锁后调用wait,进入wait状态)



-----

##### MonitorEnter

```java
synchronize(lock) {             // monitor_enter
  aaa
  lock.wait()
  bbb
}                              // monitor_exit
```

<https://www.jianshu.com/p/c5058b6fe8e5>

掠过偏向锁/轻量锁，直接到最直白的重量级锁，假设已经膨胀到重量级锁，那么已经有了 一个objeceMonitor

```
1、通过omAlloc方法，获取一个可用的ObjectMonitor monitor，并重置monitor数据；
2、通过CAS尝试将Mark Word设置为markOopDesc:INFLATING，标识当前锁正在膨胀中，如果CAS失败，说明同一时刻其它线程已经将Mark Word设置为markOopDesc:INFLATING，当前线程进行自旋等待膨胀完成；
3、如果CAS成功，设置monitor的各个字段：_header、_owner和_object等，并返回；
```

当一个线程进入monitor_enter时，判断monitor的owner,  

* 不为当前线程即block, 当前线程封装成ObjectWaiter,进入blockSet 

* 持锁, 设owner, 运行临界代码段

<https://www.jianshu.com/p/c5058b6fe8e5>

JVM里的block实现：

线程加入队列头，自旋尝试成为owner,  尝试失败->调用park，挂起objectWaiter.javathread，否则跳出自旋。

objectWaiter被唤醒时候，会再次尝试成为owner

##### MonitorExit

MonitorExit 时候，根据某种策略从block队列里，取一个obejctwaiter,调用unpark唤醒线程。 让那个object waiter去尝试成为owner.

___

##### wait

<https://www.jianshu.com/p/f4454164c017>

wait调用时已经持有 monitor, 调用放弃monitor owner( 调用monitor exit), 线程封装成ObjectWaiter 进入waitingSet, park当前线程

##### notify

notify调用时已经持锁，从waitingSet中获取某个objectWaiter, 令其自旋拿锁，并不会放弃锁。



> 从JVM的方法实现中，可以发现：notify和notifyAll并不会释放所占有的ObjectMonitor对象，其实真正释放ObjectMonitor对象的时间点是在执行monitorexit指令，一旦释放ObjectMonitor对象了，entry set中ObjectWaiter节点所保存的线程就可以开始竞争ObjectMonitor对象进行加锁操作了。



