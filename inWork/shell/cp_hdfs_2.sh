#!/bin/bash
folderList="$1"
targetNode="$2"
while read -r line; do
    folder="$line"
    echo "begin to copy folder - $folder" 
    ssh -n -i /root/aws/hgos.pem ec2-user@$targetNode "mkdir -p /home/ec2-user/40-node-backup/$folder" 

    # list the folders
    hadoop fs -ls -R $folder > tmp_file_contents_to_$targetNode
    while read -r innerLine; do
	echo $innerLine
        innerFile=`echo $innerLine | cut -d " " -f 1-7 --complement`
        echo $innerFile
        if [[ $innerLine == d* ]]
        then
        	ssh -n -i /root/aws/hgos.pem ec2-user@$targetNode "mkdir -p /home/ec2-user/40-node-backup/$innerFile"
        else
               simpleFileName=${innerFile##*/}
               fileDirectory=${innerFile%/*}
               hadoop fs -get $innerFile ./
               echo "downloaded file - $innerFile"
               echo "begin to scp the file to $targetNode :/home/ec2-user/40-node-backup"
               scp -i /root/aws/hgos.pem $simpleFileName ec2-user@$targetNode:/home/ec2-user/40-node-backup/$fileDirectory
               echo "done copy the file - $innerFile , delete the file"
               rm $simpleFileName
         fi

    done < "tmp_file_contents_to_$targetNode"
     
   echo "end to copy folder - $folder"
done < "$folderList"
