[TOC]

## environment

**Local-10node**: hadoopName=10.20.127.17;BDEIP=10.197.100.128;

**CTC_CDH_5.12**: hadoopName=nameservice1; BDEIP=10.197.34.213;



hadoopName=10.20.127.17; hdfsPort=8020; BDEHTTPPort=5020; BDEIP=10.197.100.128; BDEPORT=40004; ACL=0; 

## sbt

todo



## shell

#### 1. common commands 

for i in {23..29}; do grep -r "sourceDbId=0" engine.2017-08-$i.log; echo $ i; done

for i in {3..40}; do ping -c 4 10.242.109.$i; echo "=========$i========"; done > ping.log

du -lh --max-depth=1

find . -name job-server-local.log

awk '{print $2,$4,$6,$8}' Msi_cp > fromMSI



tar --use-compress-program=lbzip2 -cf - $1 > /dev/tcp/​${2/://}

cat < /dev/tcp/${1/://} | tar --use-compress-program=lbzip2 -xvf -

#### 2. script to clean files no logger modified in last 7 days

```shell
#!/bin/bash
PATH=/usr/bin:/bin
export PATH
 
GAP_Day='9'
 
SOURCEPATH='/tmp/ndc/job_log/'
TARGETPATH='/tmp/ndc/clean_log/'
 
cleanExpireDir(){
  echo "start to clean:"$1 >> $TARGETPATH/log
  expireDir=`find $1 -mtime +$GAP_Day -type d`
  len=`find $1 -mtime +$GAP_Day -type d | wc -l`
  if [[ $len -eq 1 && $expireDir"x" == $1"x" ]]
  then
     expireFileCount=`find $1 -mtime +$GAP_Day -type f | wc -l`
     totalFileCount=`ls $1 | wc -l`
     if [ $expireFileCount = $totalFileCount ]
      then
       echo "prepare to delete:"$expireDir >> $TARGETPATH/log
       currentTime=`date "+%Y-%m-%d %H:%M:%S" `
       modifyTime=`stat $1 | grep Modify | cut -c 9-27`
       echo "$currentTime" >> $TARGETPATH/log
       echo "file lastModify $modifyTime" >> $TARGETPATH/log
       echo "start delete $SOURCEPATH $1" >> $TARGETPATH/log
       rm -r $1
       echo -e "delete successfully!\n" >> $TARGETPATH/log
     fi
  else
    for name in $expireDir
    do
      if [ $name"x" != $1"x" ]
      then
         cleanExpireDir $name
      fi
    done
  fi
}
 
prepare(){
  if [ -f  $TARGETPATH/log ]
  then
      rm $TARGETPATH/log
  fi
}
 
prepare
cleanExpireDir $SOURCEPATH
```

