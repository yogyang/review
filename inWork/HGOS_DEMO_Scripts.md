### HGOS Startup In Local Mode

1. In this demo, you will learn to install microstrategy hadoop gateway 

2. At the first step, download the hgos tar to your installation directory.

3. Now untar it by executing the given command

4. Now check the prerequisite for hadoop gateway : Hadoop cluster and java

5. Check whther the Hadoop is installed by *hadoop version*

6. Check whether the Hadoop is running well by *hadoop fs -ls /*

7. Check java verison, hadoop gateway only support local mode for Spark2.3. And Spark2.3 requires java 1.8+

8. Now cd into the spark2.3 folder for your local mode startup.

9. Now you need to generate the hgos-spark.properties to configurate your hadoop gateway. Copy the template configuratoin for local mode by executing the given command, and edit the configuration as your own need. Note if your Hadoop cluster is under kerberos authentication, edit the security setting in your hgos-spark.properties according to your principle.

10. As this hadoop cluster is running with kerberos.  And we have copied the keytab file for user MSTRSVRSvc  to this machine, we edit the setting to make the hadoop gateway can communicate with hadoop cluster. 

11. You can also edit your application name by editting the spark.app.name

12. For local mode, you need to check whther your hadoop is running in High Available (HA) mode. Check this by visiting your cluster manager. e.g.  In Cloudera Manager, Click Main Page → HDFS  → NameNodes→  Federation and High Availability.

    If your Hadoop is running in HA mode,  then copy the Hadoop-related config files to lib/. This is required specifically for local mode startup with Hadoop HA mode.

    If your Hadoop is not running in HA mode, just run ./sbin/start-hgos.sh to start the Hadoop gateway.

13. Now  let's check whether the Hadoop is running in HA.

14. Ok, we need to copy the Hadoop-related config . First, find the Hadoop conf folder by *hadoop classpath*.

    The conf folder is quite obvious. 

14. Then copy the the *core-site.xml, hdfs-site.xml, mapred-site.xml, ssl-client.xml, yarn-site.xml* from the Hadoop conf folder ( in our example, it's /etc/hadoop/conf ) to the lib/
15. Finally, Let's start the hadoop gateway.
16. Now your hadoop gateway is running in local mode successfully.



### HGOS Startup In Yarn-Client Mode

1. In this demo, you will learn to install microstrategy hadoop gateway and start up it in yarn-client mode on a linux machine. 
2. At the first step, download the hgos tar to your installation directory.
3. Now untar it by executing the given command
4. Now check the prerequisite for hadoop gateway : Hadoop cluster, java and spark
5. Check whther the Hadoop is installed by *hadoop version*
6. Check whether the Hadoop is running well by *hadoop fs -ls /*
7. Check java verison, it's required java 1.7+ for spark 1.6 and  java 1.8+ for spark2+
8. Check your spark version by executing the given command. 
9. In this machine, we do have both Spark1.6 and Spark2.3. We pick spark1.6 in this demo.
10. Now you need to generate the hgos-spark.properties to configurate your hadoop gateway. Copy the template configuratoin for local mode by executing the given command, and edit the configuration as your own need. Note if your Hadoop cluster is under kerberos authentication, edit the security setting in your hgos-spark.properties according to your principle.
11. As this hadoop cluster is running with kerberos.  And we have copied the keytab file for user MSTRSVRSvc  to this machine, we edit the setting to make the hadoop gateway can communicate with hadoop cluster. 
12. You can also edit your application name by editting the spark.app.name
13. Finally, Let's start the hadoop gateway.

### HGOS Status Check

1. In this demo, you will learn to Five ways to check whether microstrategy hadoop gateway is running well

2. First check the console output from your start command, if the out is not "Start success." Then, the hadoop gateway is not working!

3. Check the log,  after the Hadoop Gateway is started, there should be a **log/** folder generated, check the log/hgos.out to see if there is ERROR there

4. Use jps the grep the process,  use `jps -v | grep Spark` check if there is process running and whether the process is your expected Hadoop Gateway process.  Note, If you're in local mode, use `jps -v | grep LightingServer` instead. 

5. Check the ports. If HGOS is running well, the http port ( 4020 by default ) and the tcp port (30004 by default) should be used. Check the ports is also a way to check the HGOS's status

6. check the spark UI. If HGOS is running well, there spark ui should be prepared. check the sparkUI with your-machine-with-HGOS-ip:4040, and you should get the page like below:
