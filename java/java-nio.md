[TOC]

## Java NIO

要理解NIO(New IO/ Non-Blocking IO)，需要先对最原始的I/O进行对比。I/O即Input/Output，输入/输出是编程语言在屏蔽了所有底层的实现后给的一个统一接口，开发者无需再去适配输入端是键盘、手写版、文件甚至网络流，对输出同理。

###传统I/O

传统的Java I/O方式以流(stream)的方式对输入输出进行处理，*面向流* 的 I/O 系统一次一个字节地处理数据。一个输入流产生一个字节的数据，一个输出流消费一个字节的数据。在Java中也就对应着InputStream, OutputStream以及一系列扩展的子类。示例代码

```
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



### NIO

NIO 以块的方式处理数据, 一个 *面向块* 的 I/O 系统以块的形式处理数据。每一个操作都在一步中产生或者消费一个数据块。按块处理数据比按(流式的)字节处理数据要快得多。

且NIO中read,write都是**非阻塞**的。



 