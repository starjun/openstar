#!/bin/bash

# bash 版本
version=0.2

url=http://10.112.29.56/
c=1000
n=100000
forn=10
all=0
if [ "$1" = "install" ];then
     yum install -y httpd-tools bc
elif [ "$1" = "test" ]; then
	if [ "$2" = "k" ];then
		for((i=1;i<=${forn};i++));do
	    rps=`ab -n ${n} -k -c ${c} ${url} |grep "Requests per second" | awk '{print $4}'`
	    all=$(echo "${all}+${rps}"|bc)
	    echo ${rps}
		done
		avg=$(echo "scale=2;${all}/${forn}"|bc)
		echo "avg is ${avg}"
	else
		for((i=1;i<=${forn};i++));do
	    rps=`ab -n ${n} -c ${c} ${url} |grep "Requests per second" | awk '{print $4}'`
	    all=$(echo "${all}+${rps}"|bc)
	    echo ${rps}
		done
		avg=$(echo "scale=2;${all}/${forn}"|bc)
		echo "avg is ${avg}"
	fi
else
    echo "it is ab test!"
fi
