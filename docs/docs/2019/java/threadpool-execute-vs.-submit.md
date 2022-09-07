# ThreadPool execute vs. submit

\[TOC]

## ThreadPool execute vs. submit

之前一直写代码一直有个理念，涉及到线程池中task的try catch一定要catch Throwable,否则java 若发生了Error，则线程池中的执行该task的线程会直接异常退出，且在外部无任何log打出。

后一同事在试验时，发现并不是这么一回事，即

### 问题

fixed线程池里固定三个线程，向线程池里提交4个任务，若某个task(task-2)执行异常没有被捕捉到，会发生什么？

1. 我一直的想法： 异常未捕捉到的线程直接挂掉，没有任何错误输出，而线程池自己会再拉一个新线程起来。即这时候如果对程序进行jvm dump，会看到线程池中还有3个线程。后期开发如果去日志里排查，完全看不出task-2是如何异常结束了的。

那经过实践，发现并不是这样：

```java
package com.yyj.test;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicInteger;

public class ThreadPoolTest {
    public static void main(String... args) {
        ExecutorService executorService = Executors.newFixedThreadPool(3,
                new ThreadFactory() {
                    private AtomicInteger counter = new AtomicInteger(0);
                    public Thread newThread(Runnable r) {
                        return new Thread(r, "thread-" + counter.incrementAndGet());
                    }
                });

        for (int i = 0; i < 4; i++) {
            executorService.execute(new Task(i));
        }

    }

    static class Task implements Runnable {

        private int id;

        Task(int id) {
            this.id = id;
        }

        public void run() {
            try {
                if (id == 2) {
                    throw new OutOfMemoryError("test not caught");
                }
                System.out.println(Thread.currentThread().getName() + ": task-" + id + " is designed to be done");
            } catch (Exception e) {
                System.out.println("caught exception");
            }
        }
    }
}
```

输出：

```
thread-1: task-0 is designed to be done
thread-2: task-1 is designed to be done
thread-1: task-3 is designed to be done
Exception in thread "thread-3" java.lang.OutOfMemoryError: test not caught
	at com.yyj.test.ThreadPoolTest$Task.run(ThreadPoolTest.java:35)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1142)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
	at java.lang.Thread.run(Thread.java:745)
```

jvm dump,线程池中线程为thread-1, thread-2, thread-4:

```
"thread-4" #13 prio=5 os_prio=31 tid=0x00007fb88c028000 nid=0x3e03 waiting on condition [0x000070000810a000]
   java.lang.Thread.State: WAITING (parking)
	at sun.misc.Unsafe.park(Native Method)
	- parking to wait for  <0x00000007aac93f28> (a java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject)
	at java.util.concurrent.locks.LockSupport.park(LockSupport.java:175)
	at java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject.await(AbstractQueuedSynchronizer.java:2039)
	at java.util.concurrent.LinkedBlockingQueue.take(LinkedBlockingQueue.java:442)
	at java.util.concurrent.ThreadPoolExecutor.getTask(ThreadPoolExecutor.java:1067)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1127)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
	at java.lang.Thread.run(Thread.java:745)

"thread-2" #11 prio=5 os_prio=31 tid=0x00007fb88c026800 nid=0x4103 waiting on condition [0x0000700007f04000]
   java.lang.Thread.State: WAITING (parking)
	at sun.misc.Unsafe.park(Native Method)
	- parking to wait for  <0x00000007aac93f28> (a java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject)
	at java.util.concurrent.locks.LockSupport.park(LockSupport.java:175)
	at java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject.await(AbstractQueuedSynchronizer.java:2039)
	at java.util.concurrent.LinkedBlockingQueue.take(LinkedBlockingQueue.java:442)
	at java.util.concurrent.ThreadPoolExecutor.getTask(ThreadPoolExecutor.java:1067)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1127)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
	at java.lang.Thread.run(Thread.java:745)

"thread-1" #10 prio=5 os_prio=31 tid=0x00007fb88b84a800 nid=0x4303 waiting on condition [0x0000700007e01000]
   java.lang.Thread.State: WAITING (parking)
	at sun.misc.Unsafe.park(Native Method)
	- parking to wait for  <0x00000007aac93f28> (a java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject)
	at java.util.concurrent.locks.LockSupport.park(LockSupport.java:175)
	at java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject.await(AbstractQueuedSynchronizer.java:2039)
	at java.util.concurrent.LinkedBlockingQueue.take(LinkedBlockingQueue.java:442)
	at java.util.concurrent.ThreadPoolExecutor.getTask(ThreadPoolExecutor.java:1067)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1127)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
	at java.lang.Thread.run(Thread.java:745)
```

即，结果是：

**未捕获的异常被打印出来**，thread-3在执行task-2时候，异常退出了，**线程池再启动了一个thread-4来替换thread-3.**

so...我之前的想法一直是错的？？但是项目里明明之前就碰到过线程池中task exception没有被catch到，而log中无任何输出，导致我找bug找了好一阵。

所以到这里，已经跟我最开始的想法的出入是:

**未被catch的异常被打印出来了（我一直的印象是 线程里的异常若没被catch住，会导致后续排查中找不到该线程异常退出的日志，令问题排查十分困难）**

### 分析

于是，去看项目里的代码，发现项目里线程池提交任务用的是**submit**接口。

即上述代码中提交任务的代码改为：

```java
executorService.submit(new Task(i));
```

那么输出变成：

```
thread-1: task-0 is designed to be done
thread-2: task-1 is designed to be done
thread-1: task-3 is designed to be done
```

jvm dump，线程池中线程为thread-1, thread-2, thread-3：

```java
"thread-3" #12 prio=5 os_prio=31 tid=0x00007fca97062800 nid=0x4003 waiting on condition [0x0000700009e0d000]
   java.lang.Thread.State: WAITING (parking)
	at sun.misc.Unsafe.park(Native Method)
	- parking to wait for  <0x00000007aac94078> (a java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject)
	at java.util.concurrent.locks.LockSupport.park(LockSupport.java:175)
	at java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject.await(AbstractQueuedSynchronizer.java:2039)
	at java.util.concurrent.LinkedBlockingQueue.take(LinkedBlockingQueue.java:442)
	at java.util.concurrent.ThreadPoolExecutor.getTask(ThreadPoolExecutor.java:1067)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1127)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
	at java.lang.Thread.run(Thread.java:745)

"thread-2" #11 prio=5 os_prio=31 tid=0x00007fca97030800 nid=0x4403 waiting on condition [0x0000700009d0a000]
   java.lang.Thread.State: WAITING (parking)
	at sun.misc.Unsafe.park(Native Method)
	- parking to wait for  <0x00000007aac94078> (a java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject)
	at java.util.concurrent.locks.LockSupport.park(LockSupport.java:175)
	at java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject.await(AbstractQueuedSynchronizer.java:2039)
	at java.util.concurrent.LinkedBlockingQueue.take(LinkedBlockingQueue.java:442)
	at java.util.concurrent.ThreadPoolExecutor.getTask(ThreadPoolExecutor.java:1067)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1127)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
	at java.lang.Thread.run(Thread.java:745)

"thread-1" #10 prio=5 os_prio=31 tid=0x00007fca9682d800 nid=0x3e03 waiting on condition [0x0000700009c07000]
   java.lang.Thread.State: WAITING (parking)
	at sun.misc.Unsafe.park(Native Method)
	- parking to wait for  <0x00000007aac94078> (a java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject)
	at java.util.concurrent.locks.LockSupport.park(LockSupport.java:175)
	at java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject.await(AbstractQueuedSynchronizer.java:2039)
	at java.util.concurrent.LinkedBlockingQueue.take(LinkedBlockingQueue.java:442)
	at java.util.concurrent.ThreadPoolExecutor.getTask(ThreadPoolExecutor.java:1067)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1127)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
	at java.lang.Thread.run(Thread.java:745)
```

可以看到结果是：

**异常无任何输出，且thread-3并没有因为我们task逻辑里未捕获的异常而退出**。

那么为什么会这样呢，其实首先就是execute和submit接口区别的认知不清楚导致的。

#### execute

之前看过execute代码之前看过，就是按照线程池的执行策略立即执行task或将task放入queue中等等，而worker中执行task的逻辑里：

```java
while (task != null || (task = getTask()) != null) {
                w.lock();
                // If pool is stopping, ensure thread is interrupted;
                // if not, ensure thread is not interrupted.  This
                // requires a recheck in second case to deal with
                // shutdownNow race while clearing interrupt
                if ((runStateAtLeast(ctl.get(), STOP) ||
                     (Thread.interrupted() &&
                      runStateAtLeast(ctl.get(), STOP))) &&
                    !wt.isInterrupted())
                    wt.interrupt();
                try {
                    beforeExecute(wt, task);
                    Throwable thrown = null;
                    try {
                        task.run();
                    } catch (RuntimeException x) {
                        thrown = x; throw x;
                    } catch (Error x) {
                        thrown = x; throw x;
                    } catch (Throwable x) {
                        thrown = x; throw new Error(x);
                    } finally {
                        afterExecute(task, thrown);
                    }
                } finally {
                    task = null;
                    w.completedTasks++;
                    w.unlock();
                }
```

对于用户传入的task，进行了全面的异常捕捉，不会漏掉exception,并直接throw 给线程，而线程在碰到运行异常时候，会在console里打印出异常 ，而线程终止。即上述看到的，**控制台**打出异常，**thread-3异常退出**。

#### submit

submit的代码如下，可以看到用java对用户提交的task进行了一层封装，封装成了RunnableFuter，而在RunnableFuter里对task抛出进行了Throwable的catch,将异常放在futer的结果里进行了返回。而不是直接抛回给了线程。即异常被**内部消化处理掉，在线程上无异常，thread-3不会发生异常退出**。

```java
public Future<?> submit(Runnable task) {
        if (task == null) throw new NullPointerException();
        RunnableFuture<Void> ftask = newTaskFor(task, null);
        execute(ftask);
        return ftask;
    }
```

FutureTask.java

```java
Callable<V> c = callable;
            if (c != null && state == NEW) {
                V result;
                boolean ran;
                try {
                    result = c.call();
                    ran = true;
                } catch (Throwable ex) {
                    result = null;
                    ran = false;
                    setException(ex);
                }
                if (ran)
                    set(result);
            }
```

#### execute vs. submit

**从接口上看**：

1. execute：旨在向线程池中提交给任务，并**不需要获取任务的返回值**
2. submit： 旨在向线程池中提交给任务，并**通过future来获取任务的返回值**，比如task的执行结果，如果任务异常了那么在futer.get()时抛出异常

从异常处理上看：

1. execute: 直接将异常抛给thread，会导致线程的异常退出
2. submit: 内部逻辑消化掉了异常，并将异常封装在future内，不会导致线程的退出。

#### catch Throwable?

那么关于另外一个问题

```
未被catch的异常被打印出来了（我一直的印象是 线程里的异常若没被catch住，会导致后续排查中找不到该线程异常退出的日志，令问题排查十分困难）
```

这个怎么解释？

其实很简单，要明确两点

1. thread在遇到异常时，默认情况下是直接在**控制台**输出异常堆栈日志的
2. 在正式生产环境，日志都是通过日志框架按天迭代打印到**文件**的

那么以下一段代码中线程的异常退出，在**日志文件**中无法看到任务输出，

main.java

```java
 ExceptionRunnale fakeWorker = new ExceptionRunnale();
 fakeWorker.start();

    static class ExceptionRunnale implements Runnable {

        private Thread thread;

        private static Logger logger = LoggerFactory.getLogger(ExceptionRunnale.class);

        public void start(){
            thread = new Thread(this,"ExceptionRunnale-thread");
            thread.start();
        }


        public void run() {
            try {
                logger.info("expect all log");
                throw new OutOfMemoryError("test exception");
            } catch (Exception e) {
                logger.error("we met error!!!!");
            }

        }
    }
```

在日志文件中，我们只能看到：

```
2018/10/03 13:51:15,377 Wed INFO test.ThreadPoolTest$ExceptionRunnale: expect all log
```

而异常的日志在控制台中：

```
Exception in thread "ExceptionRunnale-thread" java.lang.OutOfMemoryError: test exception
	at com.yyj.test.ThreadPoolTest$ExceptionRunnale.run(ThreadPoolTest.java:75)
	at java.lang.Thread.run(Thread.java:745)
```

那么试想下，在生产环境中，若在thread里的task里有未catch到的exception，那么thread 异常退出，而日志文件里看不到任何输出，会让后续的排查十分困惑。若在task里catch throwable，则首先thread不会不受控制的异常退出，再则日志中也能直接看到thread 内task 出现过异常，也方便后续排查。
