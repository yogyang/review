### Kafka

| 操作                        | 命令                                                         |
| --------------------------- | ------------------------------------------------------------ |
| 查看所有topic               | bin/kafka-topics.sh --zookeeper node01:2181 --list           |
| 查看topic信息               | bin/kafka-topics.sh --zookeeper node01:2181 --describe --topic t_cdr |
| 查看topic偏移量信息         | bin/kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list cdh6:9092 --topic normal-tollgate --time -1 |
| 终端消费消息                | bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test.1 --from-beginning |
| 查看consumer groups         | bin/kafka-consumer-groups.sh --zookeeper 127.0.0.1:2181 --list<br /><br />bin/kafka-consumer-groups.sh --new-consumer --bootstrap-server 127.0.0.1:9092 --list |
| 查看特定consumer group 详情 | bin/kafka-consumer-groups.sh --new-consumer --bootstrap-server 127.0.0.1:9092 --group lx_test --describe |





----

### Docker

#### 查看

docker ps

docker container/image ls

#### 启动

| 操作 | 命令 |	示例 |
| --- | --- | --- |
| 创建 container	| docker create	| docker create kafka/2.1 |
|  创建并运行 container | docker run |	docker run chenhengjie123/xwalkdriver /bin/bash |
| 创建并运行 container 后进入其 bash 控制台 | 	docker run -t -i image /bin/bash | 	docker ru n -t -i ubuntu /bin/bash|
| 创建并运行 container 并让其在后台运行，并端口映射 |	docker run -p [port in container]:[port in physical system] -d [image] [command]	| docker run -p 5000:5000 -d training/webapp python app.py |
|  进入已经启动的container console | docker exec -it container_id /bin/bash | docker exec -it 775c7c9ee1e1 /bin/bash |
| 查看正在运行的所有 container 信息 |	docker ps	 | docker ps |
| 查看最后创建的 container | 	docker ps -l	| docker ps -l |
| 查看所有 container ，包括正在运行和已经关闭的 | 	docker ps -a	| docker ps -a |
| 输出指定 container 的 stdout 信息（用来看 log ，效果和 tail -f 类似，会实时输出。）| docker logs -f [container] |	docker logs -f nostalgic_morse |
| 获取 container 指定端口映射关系	 | docker port [container] [port] | 	docker port nostalgic_morse 5000 |
| 查看 container 进程列表	| docker top [container]	| docker top nostalgic_morse |
| 查看 container 详细信息	| docker inspect [container]	| docker inspect nostalgic_morse |
| 停止 continer	| docker stop [container]	 | docker stop nostalgic_morse |
| 强制停止 container |	docker kill [container]	 | docker kill nostalgic_morse |
| 启动一个已经停止的 container	| docker start [container]	| docker start nostalgic_morse |
| 重启 container (若 container 处于关闭状态，则直接启动)	| docker restart [container]	|docker restart nostalgic_morse |
| 删除 container |	docker rm [container]	| docker rm nostalgic_morse |

