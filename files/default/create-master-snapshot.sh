#!/bin/bash

#check_master_snapshot
size=`ls -l check_master_snapshot | awk '{print $5}'`
echo $size
if [ $size -eq 0 ]; then
        echo $1 $2 $3 $4 $5 $6 $7 $8 $9

        MYACCESSKEY="$1"
        MYSECRETKEY="$2"
        EC2_CERT=/home/ubuntu/_cert-tu-snapshot.pem
        EC2_PRIVATE_KEY=/home/ubuntu/_pk-tu-snapshot.pem
        instanceid="$3"
        availability_zone="$4"
        length=${#availability_zone}
        let newlength=$length-1
        region=`echo $availability_zone | cut -c -$newlength`
        device="$5"
        device_letters=`echo $device | cut -c 6-`
        filesystem="$6"
        mysqlsocket="/var/run/mysqld/mysqld.sock"
        snaplabel="$7-$8-$device_letters-"
        #this is only working with the aws (perl) tools
        volumeid=`ec2-describe-volumes --region $region --private-key $EC2_PRIVATE_KEY --cert $EC2_CERT | grep $instanceid | grep "$device" | cut -f2`
        echo $volumeid
	user=root
        password="$9"
	host="$10"
        ec2-consistent-snapshot --aws-access-key-id $MYACCESSKEY --aws-secret-access-key $MYSECRETKEY --region $region --freeze-filesystem $filesystem --mysql --mysql-host $host --mysql-socket $mysqlsocket --mysql-username $user --mysql-password $password --description $snaplabel`date +"%Y-%m-%d-%H:%M:%S"` $volumeid
        /usr/bin/aws dsnap --region $region | grep $volumeid | sort -r -k 5  | sed 1,7d | awk '{print "Deleting snapshot: " $2 " Dated:" $8};system("/usr/bin/aws delsnap --region $region " $2 )'

fi

