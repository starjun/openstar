#!/bin/bash

# 脚本版本号
version=0.4

down_path_redis=/opt/redis
redis_version=5.0.3
down_url=http://download.redis.io/releases/redis-${redis_version}.tar.gz

install_path_redis=/opt/redis/redis-${redis_version}
redis_cli=${install_path_redis}/src/redis-cli
redis_server=${install_path_redis}/src/redis-server
ip=127.0.0.1
psd=yesorno
port=6379

if [ "$1" = "start" ];then

    ${redis_server} ${install_path_redis}/redis.conf &

elif [ "$1" = "stop" ]; then

    ${redis_cli} -h ${ip} -p ${port} -a ${psd} shutdown &


elif [ "$1" = "install" ]; then
    mkdir -p ${down_path_redis}
    cd ${down_path_redis}
    wget ${down_url}
    tar zxvf redis-${redis_version}.tar.gz
    cd redis-${redis_version}
    make

elif [ "$1" = "h" ]; then

    echo "./rds.sh start/stop/install/null"

else

    ${redis_cli} -h ${ip} -a ${psd} -p ${port}

fi