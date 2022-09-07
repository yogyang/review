# ThreadPool

***

Java线程池是java cocurrent包下提供的类，使用非常方便。本文希望整理下Java 线程池相关的知识以及其实现原理。

***

### 类结构

Executors, ExecutorService, ThreadPoolExecutor等概念，各个类容易混淆，其实类关系整理如图。ExecutorService接口扩展了Executors接口，在基本的execute()方法上，提供了一些线程池管理方法、同步／异步获取线程执行结果的方法。 ![屏幕快照 2017-06-28 下午11.10.32.png](http://upload-images.jianshu.io/upload\_images/4849306-1ab441f48eddd7fc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240) 通常，我们使用线程池的模版代码如下

```
ExecutorService executorService = Executors.newFixedThreadPool(5,
                new ThreadFactory() {
                    private AtomicInteger count = new AtomicInteger(0);
                    @Override
                    public Thread newThread(Runnable r) {
                        return new Thread("task thread-" + count.incrementAndGet());
                    }
                });
 for (int i = 0; i < 10; i++) {
      executorService.submit(new Task());
}
```

从类图结构就可以很好的理解了， Executors即为工厂方法类，提供多种类型线程池的构造。ExecutorService即为所有线程池的接口类。 我们使用的线程池可以分为两类ScheduledExecutorService、ThreadPoolExecutor。实际所有线程池均为其实现类或者wrapper类。所以分析线程池可以从这两类入手。

***

### ThreadPoolExecutor

常用的代表有Executors.newFixedThreadPool(),newCachedThreadPool() 等，构造出来的都是设定了不同参数的ThreadPoolExecutor实例。 ThreadPoolExecutor的核心参数有：

> * corePoolSize
> * maxPoolSize
> * keepAliveTime
> * workingQueue: 同步队列，无界队列，有界队列

具体每个参数的定义可以看Java doc,文档对于何时创建线程、何时将任务排队、以及排队策略的说明都写的非常详细。本人经常忘记的一点就是线程创建的策略：

> 1. alive线程数< corePoolSize，来一个新task则新建一个线程
> 2. alive线程数>corePoolSize，则新task先排队，排队排不下了再尝试新建线程。
> 3. 排队时队满了，尝试新建线程。线程数目到达maxPoolSize,根据定义的策略方式来处理后面继续到来的任务，比如直接拒绝任务。

***

从基本使用代码 executorService.submit(new Task());入手分析，threadPool到底做了什么？是如何让一个任务跑起来的？

\###submit 代码中可以看到，逻辑为将传入的runnable封装成一个runnableFuture,再调用execute方法执行该任务。runnableFuture可提供接口，将任务取消执行等。其他相关runnableFuture变种可以提供一些异步获取task执行返回结果的接口，具体需要看callable,future的说明。

```
 /**
     * @throws RejectedExecutionException {@inheritDoc}
     * @throws NullPointerException       {@inheritDoc}
     */
    public Future<?> submit(Runnable task) {
        if (task == null) throw new NullPointerException();
        RunnableFuture<Void> ftask = newTaskFor(task, null);
        execute(ftask);
        return ftask;
    }
```

#### execute

```
public void execute(Runnable command) {
        if (command == null)
            throw new NullPointerException();
        /*
         * Proceed in 3 steps:
         *
         * 1. If fewer than corePoolSize threads are running, try to
         * start a new thread with the given command as its first
         * task.  The call to addWorker atomically checks runState and
         * workerCount, and so prevents false alarms that would add
         * threads when it shouldn't, by returning false.
         *
         * 2. If a task can be successfully queued, then we still need
         * to double-check whether we should have added a thread
         * (because existing ones died since last checking) or that
         * the pool shut down since entry into this method. So we
         * recheck state and if necessary roll back the enqueuing if
         * stopped, or start a new thread if there are none.
         *
         * 3. If we cannot queue task, then we try to add a new
         * thread.  If it fails, we know we are shut down or saturated
         * and so reject the task.
         */
        int c = ctl.get();
        if (workerCountOf(c) < corePoolSize) {
        /* worker线程数 < corePoolSize，直接新建一个线程，且该task作为新建线程的第一个任务直接执行*/
            if (addWorker(command, true))
                return;
            c = ctl.get();
        }
        if (isRunning(c) && workQueue.offer(command)) {
        /*线程池running状态且队列中还能排下该task,则task进入队列。此时有二次检查，若二次检查不过，则task移除队列，成功移出后，调用reject策略。否则，task成功在排队队列中等待执行，若此时worker线程数＝0，则新建个线程来处理该任务*/
            int recheck = ctl.get();
            if (! isRunning(recheck) && remove(command))
                reject(command);
            else if (workerCountOf(recheck) == 0)
                /* 注意此时addWorker里第一个参数为null
                addWorker(null, false);
        }
       /*尝试直接线程，该task作为该新建线程的第一个任务*/
        else if (!addWorker(command, false))
            reject(command);
    }
```

看完有3个疑问：

> 1. 线程数目>corePoolSize时且队列中有剩余槽位时，task在队列中等待执行，则何时会被worker线程执行？ 2.线程数目>corePoolSize且队列中无剩余槽位时，task直接由新建一个线程执行（< maxPoolSize），那是否是造成了后提交的task是可能先执行的？

#### addWorker

```
private boolean addWorker(Runnable firstTask, boolean core) {
        retry:
        for (;;) {
            int c = ctl.get();
            int rs = runStateOf(c);

            // Check if queue empty only if necessary.
            if (rs >= SHUTDOWN &&
                ! (rs == SHUTDOWN &&
                   firstTask == null &&
                   ! workQueue.isEmpty()))
                return false;

            for (;;) {
                int wc = workerCountOf(c);
                if (wc >= CAPACITY ||
                    wc >= (core ? corePoolSize : maximumPoolSize))
                    return false;
                if (compareAndIncrementWorkerCount(c))
                    break retry;
                c = ctl.get();  // Re-read ctl
                if (runStateOf(c) != rs)
                    continue retry;
                // else CAS failed due to workerCount change; retry inner loop
            }
        }

        boolean workerStarted = false;
        boolean workerAdded = false;
        Worker w = null;
        try {
            final ReentrantLock mainLock = this.mainLock;
            w = new Worker(firstTask);
            final Thread t = w.thread;
            if (t != null) {
                mainLock.lock();
                try {
                    // Recheck while holding lock.
                    // Back out on ThreadFactory failure or if
                    // shut down before lock acquired.
                    int c = ctl.get();
                    int rs = runStateOf(c);

                    if (rs < SHUTDOWN ||
                        (rs == SHUTDOWN && firstTask == null)) {
                        if (t.isAlive()) // precheck that t is startable
                            throw new IllegalThreadStateException();
                        workers.add(w);
                        int s = workers.size();
                        if (s > largestPoolSize)
                            largestPoolSize = s;
                        workerAdded = true;
                    }
                } finally {
                    mainLock.unlock();
                }
                if (workerAdded) {
                    t.start();
                    workerStarted = true;
                }
            }
        } finally {
            if (! workerStarted)
                addWorkerFailed(w);
        }
        return workerStarted;
    }
```
