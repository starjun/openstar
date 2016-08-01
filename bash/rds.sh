#!/bin/bash

install_path_redis=/opt/redis/redis-3.2.1
psd=yesorno

install_path_redis=/opt/redis

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
	mkdir -p ${install_path_redis}
	cd ${install_path_redis}
	wget http://download.redis.io/releases/redis-3.2.1.tar.gz
	tar zxvf redis-3.2.1.tar.gz
	cd redis-3.2.1
	make	
else
     ${install_path_redis}/src/redis-cli -a ${psd}
fi