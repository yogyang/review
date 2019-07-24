[TOC]

## Java NIO Basic

要理解NIO(New IO/ Non-Blocking IO)，需要先对最原始的I/O进行对比。I/O即Input/Output，输入/输出是编程语言在屏蔽了所有底层的实现后给的一个统一接口，开发者无需再去适配输入端是键盘、手写版、文件甚至网络流，对输出同理。

### 传统I/O

传统的Java I/O方式以流(stream)的方式对输入输出进行处理，*面向流* 的 I/O 系统一次一个字节地处理数据。一个输入流产生一个字节的数据，一个输出流消费一个字节的数据。在Java中也就对应着InputStream, OutputStream以及一系列扩展的子类。示例代码

```java
private static void bioRead(String path) throws IOException {
        FileInputStream in = null;

        try {
            in = new FileInputStream(path);

            int c;
            while ((c = in.read()) != -1) {
                System.out.print(c);
            }
        }finally {
            if (in != null) {
                in.close();
            }
        }
    }
```

注意：

在传统I/O的接口下，所有的read, write都是**阻塞**的，以read为例，若对应的输入端当时无数据输入，则read将卡住当前线程直到输入端输入新的数据。

传统I/O是面向流的，因此，在Java传统I/O的接口下，我们可以看到各种InputStream, OutputStream.



### NIO

NIO 以块的方式处理数据, 一个 *面向块* 的 I/O 系统以块的形式处理数据。每一个操作都在一步中产生或者消费一个数据块。按块处理数据比按(流式的)字节处理数据要快得多。NIO中read,write都是**非阻塞**的。NIO中必然会提到的两个概念是 Buffer, Channel:

> 1. Buffer :NIO 中，所有数据的读写都必须写入buffer中，buffer即用户申请分配的一段数据内存，进行数据的缓存。

> 2. Channel: 通道，NIO数据的读写通过Channel, 向对应的Buffer进行数据的读写。Channel跟Stream最大的区别在于，Channel是双向的，既可以读也可以写。



![image-20190123224623469](https://raw.githubusercontent.com/fuqiliang/review/master/java/pictures/channel.png)

Sample Code From [NIO IBM](https://www.ibm.com/developerworks/cn/education/java/j-nio/j-nio.html)

 ```java
private static void nioRead(String path) throws IOException { 
    FileInputStream fileInputStream = new FileInputStream( path); 
    FileChannel inChannel = fileInputStream.getChannel();
    FileOutputStream fileOutputStream = new FileOutputStream(path+"_out");
    FileChannel outChannel = fileOutputStream.getChannel();

    //create buffer with capacity of 48 bytes
    ByteBuffer buf = ByteBuffer.allocate(48);

    int bytesRead= inChannel.read(buf); //read into buffer.

    while (bytesRead != -1){

        buf.flip();

        System.out.println("== begin to write:" + bytesRead);
        outChannel.write(buf);

        buf.clear();

        bytesRead = inChannel.read(buf);
    }

    inChannel.close();
    outChannel.close();

    fileInputStream.close();
    fileOutputStream.close();
}
 ```



Sample code的流程就是

1. 申请48bytes的ByteBuffer

2. 通过InputChannel，从inputPath中读取数据，写入ByteBuffer

3. 通过ouputChannel,  将ByteBuffer中已有数据写入 outputPath中

   
#### Buffer Basic API

简单来说，buffer可以理解成一个特定类型的数组，而这个数组要支持读取和写入。而理解Buffer就需要理解它的几个API，其实不需要特意去记那几个参数，只要知道buffer一个固定长度的数组，需要支持写入，同时支持读取当前已经写入了的数据。

那么自然而然就能理解

1.切换到buffer写入模式（从channel读取），调用compact() or clear()

既然要写入，那么就需要两个位置点： start-to-write->从哪开始写   end-to-write->最多能写到哪里

 ![image-20190123232322469](https://raw.githubusercontent.com/fuqiliang/review/master/java/pictures/buffer1.png)

start-to-write : 0 (in clear) 或者 上次写入的后的下一个地址

end-to-write : 最多就能写到数组末尾

2.切换到buffer读取模式（向channel中写入），调用flip()

既然要读取，同样也需要两个位置点：start-to-read->从哪开始读   end-to-read->最多能读到哪里

![image-20190123233222488](https://raw.githubusercontent.com/fuqiliang/review/master/java/pictures/buffer3.png)

start-to-read : 0

end-to-read: 上次写入的字节数+1 =  写入模式的start-to-write位置点

### 传统I/O Server

由于传统I/O中流的读取是阻塞的，这就直接导致了一个thread若开始读取某个stream,那么，**该thread就硬生生地被绑定在这个streaming直到流结束**。而thread阻塞住的时候，CPU是空闲的，可以另开其他的thread去占用CPU处理其他的stream.

基于传统I/O设计的server中，会首先有如下模型，建立handler线程池，每个线程处理一个stream流的读写。

![image-20190128221154843](https://raw.githubusercontent.com/fuqiliang/review/master/java/pictures/bio-server.png)

弊端：

1. 每个thread需要负责对应的stream的读写，则若一直无数据入流，则该thread被一直占据，且阻塞。即处于浪费的“空等”状态
2. server端的并发量受限于线程池的大小

### NIO Server

#### 基本模型

NIO提供Selector来提供异步I/O，

> 异步 I/O 的一个优势在于，它允许您同时根据大量的输入和输出执行 I/O。同步程序常常要求助于轮询，或者创建许许多多的线程以处理大量的连接。使用异步 I/O，您可以监听任何数量的通道上的事件，不用轮询，也不用额外的线程。  
>
> from https://www.ibm.com/developerworks/cn/education/java/j-nio/j-nio.html

用户通过向Selector注册感兴趣的channel以及对该channel感兴趣的事件。

Selector.select()方法会**阻塞**直至有对应注册事件产生。

一个简单的NIO  Server的模型如下：

![image-20190128223928684](https://raw.githubusercontent.com/fuqiliang/review/master/java/pictures/nio-server.png)

重点在于

1.通过selector.select()的阻塞，以及唤醒，selector-thread每次被唤醒时候，即可出发对应active channel的读写

2.channel.read/write均为**非阻塞** ，这一点非常重要，即**解放了当前thread必须空等**的状态，可以直接让**selector-thread进行多个channel的读写**！channel的读写其实就是内存里数据的复制。

这一点，直接就去除了thread卡在网络数据等待上的资源浪费。



但是NIO的方式下，同样也引入了新的问题

#### Message不完整

由于messageReader里存着channel.read读取的数据，而channel.read是当前有多少读多少，也就是messageReader里可能读取了0.5个，1个甚至1.3个完整的message，需要开发者自己来判断当前的bytes里到底应该如何解析。



### More to Read

1. https://tech.meituan.com/2016/11/04/nio.htm

2. https://www.ibm.com/developerworks/cn/education/java/j-nio/j-nio.html
3. http://tutorials.jenkov.com/java-nio/non-blocking-server.html
4. https://tech.meituan.com/2016/11/04/nio.html
5. https://www.jianshu.com/p/1ccbc6a348db
6. http://gee.cs.oswego.edu/dl/cpjslides/nio.pdf


