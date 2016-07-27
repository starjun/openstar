#!/bin/bash

install_path_redis=/opt/redis/redis-3.2.1
psd=yesorno

if [ "$1" = "start" ];then
     ${install_path_redis}/src/redis-server ${install_path_redis}/redis.conf &
 elif [ "$1" = "stop" ]; then
     if ["$2" = ""];then
         ${install_path_redis}/src/redis-cli -a ${psd} shutdown &
     else
         ${install_path_redis}/src/redis-cli -p $2 -a ${psd} shutdown &
     fi
 else
         ${install_path_redis}/src/redis-cli -a ${psd}
 fi