In this demo, you will learn to install microstrategy hadoop gateway on spark and start up it in local mode on a linux machine. 

We can call it HGOS for short of Hadoop gateway on Spark.



At the first step, download the hgos tar file to your installation directory.



Untar it



Now check the prerequisite for hgos: Hadoop cluster and java,

Check whether Hadoop is installed and working well by executing the given commands





Check java version, HGOS only support local mode for spark 2.3 which requires java 8+

Now go into the spark2.3/ folder for your local mode start-up



You need to generate the hgos-spark.properties to configurate your HGOS

Copy the template config for local mode by executing the given command and edit the configurations as your own need

Note that if your Hadoop cluster is under kerberos authentication, edit the security setting in your hgos-spark.properties according to your principle.



As this Hadoop cluster is running with kerberos, and we have already copied the keytab file for principle MSTRSVRSvc to this machine, we should edit the security setting to make the HGOS can communicate with the cluster with the right principle



For local mode, you need to check whether your hadoop is running in High Available (HA) mode. Check this by visiting your cluster manager. e.g.  In Cloudera Manager, Click Main Page → HDFS  → NameNodes→  Federation and High Availability.



If your Hadoop is running in HA mode,  then copy the Hadoop-related config files to lib/. This is required specifically for local mode startup with Hadoop HA mode.

If your Hadoop is not running in HA mode, just run ./sbin/start-hgos.sh to start the Hadoop gateway.



As our hadoop is running in HA mode, we need to copy the Hadoop-related config . First, find the Hadoop conf folder by *hadoop classpath*.

The conf folder is quite obvious. 

Then copy the the five config files from the Hadoop conf folder ( in our example, it's /etc/hadoop/conf ) to the lib/

Finally, Let's start the hadoop gateway.

Now your hadoop gateway is running in local mode successfully.













