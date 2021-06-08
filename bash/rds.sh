#!/bin/bash

# 脚本版本号
version=0.6

down_path_redis=/opt/redis
mkdir -p ${down_path_redis}
redis_version=6.2.4
down_url=http://download.redis.io/releases/redis-${redis_version}.tar.gz
redis_md5=c21b0efe38a5cbd58874c72c5bddc7e7
## 5.0.3 c21b0efe38a5cbd58874c72c5bddc7e7
down_redis(){
    cd ${down_path_redis}
    if [ ! -f "redis-${redis_version}.tar.gz" ]; then
        echo "redis-${redis_version}.tar.gz 文件不存在  需要下载！"
        wget ${down_url} || (echo "${Error}wget redis Error!!" && exit 1)
    else
        # 文件存在检查 md5
        redis_now=`md5sum redis-${redis_version}.tar.gz|awk '{print $1}'`
        if [ "${redis_now}" = "${redis_md5}" ]; then
            echo "redis-${redis_version}.tar.gz md5 ok!"
        else
            echo "redis-${redis_version}.tar.gz 文件 md5 不正确"
            rm -rf redis-${redis_version}.tar.gz
            wget ${down_url} || (echo "${Error}wget redis Error!!" && exit 1)
        fi
    fi
}

install_path_redis=/opt/redis/redis-${redis_version}
redis_cli=${install_path_redis}/src/redis-cli
redis_server=${install_path_redis}/src/redis-server
ip=127.0.0.1
psd=nihaoredis123
port=6379
sed_conf(){
    file=/opt/redis/redis-${redis_version}/redis.conf
    # 修改监听IP    bind 127.0.0.1
    sed -i "s/^bind .*/bind ${ip}/g" ${file}
    # 修改监听PORT    port 6379
    sed -i "s/^port .*/port ${port}/g" ${file}
    # 修改密码 # requirepass foobared
    sed -i "s/^# requirepass .*/requirepass ${psd}/g" ${file}
    sed -i "s/^requirepass .*/requirepass ${psd}/g" ${file}
    # 修改dump路径  dir ./
    sed -i "s#^dir .*#dir ${down_path_redis}/#g" ${file}
    # 修改log路径 logfile ""
    sed -i "s#^logfile .*#logfile \"${down_path_redis}/redis.log\"#g" ${file}
}

if [ "$1" = "start" ];then

    ${redis_server} ${install_path_redis}/redis.conf &

elif [ "$1" = "stop" ]; then

    ${redis_cli} -h ${ip} -p ${port} -a ${psd} shutdown &

elif [ "$1" = "cfg" ]; then
    sed_conf

elif [ "$1" = "install" ]; then
    down_redis
    cd ${down_path_redis}
    tar zxvf redis-${redis_version}.tar.gz
    cd redis-${redis_version}
    make

elif [ "$1" = "h" ]; then

    echo "./rds.sh start/stop/install/cfg(配置reids.conf文件)/null"

else

    ${redis_cli} -h ${ip} -a ${psd} -p ${port}

fi