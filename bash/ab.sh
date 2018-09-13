#!/bin/bash

# bash 版本
version=0.3

url=http://10.112.29.56/
c=1000
n=100000
forn=10
rpsall=0
ptimeall=0
if [ "$1" = "install" ];then
     yum install -y httpd-tools bc
elif [ "$1" = "test" ]; then
    for((i=1;i<=${forn};i++));do
        if [ "$2" = "k" ];then
            list=`ab -n ${n} -c ${c} -k ${url} |grep "(mean)" | awk '{print $4}'`
            rps=`echo ${list}| awk '{print $1}'`
            ptime=`echo ${list}| awk '{print $2}'`
            rpsall=$(echo "${rpsall}+${rps}"|bc)
            ptimeall=$(echo "${ptimeall}+${ptime}"|bc)
            echo "rps: ${rps} ptime: ${ptime}"
        else
            list=`ab -n ${n} -c ${c} ${url} |grep "(mean)" | awk '{print $4}'`
            rps=`echo ${list}| awk '{print $1}'`
            ptime=`echo ${list}| awk '{print $2}'`
            rpsall=$(echo "${rpsall}+${rps}"|bc)
            ptimeall=$(echo "${ptimeall}+${ptime}"|bc)
            echo "rps: ${rps} ptime: ${ptime}"
        fi
    done
    avg=$(echo "scale=2;${rpsall}/${forn}"|bc)
    echo "rps avg is ${avg}"
    avg=$(echo "scale=2;${ptimeall}/${forn}"|bc)
    echo "ptime avg is ${avg} [ms]"
else
    echo "####################################################"
    echo "./ab.sh install 表示安装ab测试工具 （httpd-tools）"
    echo " ab 测试之前先修改一下文件配置好url -c -n 循环次数等参数 "
    echo "./ab.sh test 表示进行ab测试"
    echo "./ab.sh test k 表示进行ab -k 测试"
    echo "####################################################"
fi
