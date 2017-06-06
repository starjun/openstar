#!/bin/bash

# bash 版本
version=0.1

down_path_redis=/opt/redis
down_url=http://download.redis.io/releases/redis-3.2.1.tar.gz

install_path_redis=/opt/redis/redis-3.2.1
psd=yesorno123!@#qawe

if [ "$1" = "start" ];then

     ${install_path_redis}/src/redis-server ${install_path_redis}/redis.conf &

elif [ "$1" = "stop" ]; then
	 if ["$2" = ""];then
	     ${install_path_redis}/src/redis-cli -a ${psd} shutdown &
	 else
	     ${install_path_redis}/src/redis-cli -p $2 -a ${psd} shutdown &
	 fi

elif [ "$1" = "install" ]; then
	#yum install redis -y
	mkdir -p ${down_path_redis}
	cd ${down_path_redis}
	wget ${down_url}
	tar zxvf redis-3.2.1.tar.gz
	cd redis-3.2.1
	make	

	#echo "requirepass ${psd}" >> ${install_path_redis}/redis.conf
else

     ${install_path_redis}/src/redis-cli -a ${psd}
     
fi