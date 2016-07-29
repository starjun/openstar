#!/bin/bash
build_path=/data/openresty
install_path=/opt/openresty
install_path_redis=/opt/redis
install_version=1.9.15.1
##############################
if [ "$1" = "install" ];then
	yum install -y epel-release
	rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
	yum groupinstall -y "Development tools"
	yum install -y wget make gcc readline-devel perl pcre-devel openssl-devel git
	#############################	
	mkdir -p ${install_path}
	mkdir -p ${build_path}
	#############################	
	cd ${build_path}
	wget https://github.com/openresty/openresty/releases/download/v${install_version}/openresty-${install_version}.tar.gz
	tar zxvf openresty-${install_version}.tar.gz
	cd openresty-${install_version}
	###############################
	./configure --prefix=${install_path} --with-luajit
	gmake
	gmake install
	##############################
	cd ${install_path}	
	git clone https://github.com/starjun/openstar.git
	mv -f nginx/conf/nginx.conf nginx/conf/nginx.conf.bak
	#cp openstar/conf/nginx.conf nginx/conf/
	#cp openstar/conf/our.conf nginx/conf/
	#cp openstar/conf/waf.conf nginx/conf/
	ln -sf ${install_path}/openstar/conf/nginx.conf ${install_path}/nginx/conf/nginx.conf
	ln -sf ${install_path}/openstar/conf/waf.conf ${install_path}/nginx/conf/waf.conf
	ln -sf ${install_path}/openstar/conf/our.conf ${install_path}/nginx/conf/our.conf
	mkdir -p ${install_path}/openstar/logs
	chmod o+rw ${install_path}/openstar/logs/
	nginx/sbin/nginx

	##############################
	echo "PATH=${install_path}/nginx/sbin:\$PATH" >> /etc/profile
	export PATH

elif [ "$1" = "openstar" ]; then
	cd ${install_path}
	mv -f openstar/ openstar.bak/
	git clone https://github.com/starjun/openstar.git
	mv -f nginx/conf/nginx.conf nginx/conf/nginx.conf.bak
	mv -f nginx/conf/waf.conf nginx/conf/waf.conf.bak
	mv -f nginx/conf/our.conf nginx/conf/our.conf.bak
	#cp openstar/conf/nginx.conf nginx/conf/
	#cp openstar/conf/our.conf nginx/conf/
	#cp openstar/conf/waf.conf nginx/conf/
	ln -sf ${install_path}/openstar/conf/nginx.conf ${install_path}/nginx/conf/nginx.conf
	ln -sf ${install_path}/openstar/conf/waf.conf ${install_path}/nginx/conf/waf.conf
	ln -sf ${install_path}/openstar/conf/our.conf ${install_path}/nginx/conf/our.conf
elif [ "$1" = "redis" ]; then
	#yum install redis -y
	mkdir -p ${install_path_redis}
	cd ${install_path_redis}
	wget http://download.redis.io/releases/redis-3.2.1.tar.gz
	tar zxvf redis-3.2.1.tar.gz
	cd redis-3.2.1
	make	
else
	#### 查看服务器信息 版本、内存、CPU 等等 ####
	echo "uname －a"
	uname -a
	echo "##########################"
	echo "cat /proc/version"
	cat /proc/version
	echo "##########################"
	echo "cat /proc/cpuinfo"
	cat /proc/cpuinfo
	echo "##########################"
	echo " cat /etc/issue  或cat /etc/redhat-release"
	cat /etc/redhat-release 2>/dev/null || cat /etc/issue
	echo "##########################"
	echo "getconf LONG_BIT  （Linux查看版本说明当前CPU运行在32bit模式下， 但不代表CPU不支持64bit）"
	getconf LONG_BIT	
fi
	