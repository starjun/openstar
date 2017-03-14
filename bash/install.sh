#!/bin/bash
build_path=/data/openresty
install_path=/opt/openresty

install_version=1.11.2.2
down_uri=https://openresty.org/download/openresty-${install_version}.tar.gz
git_uri=https://github.com/starjun/openstar.git
rpm_uri=http://rpms.famillecollet.com/enterprise/remi-release-6.rpm

##############################
if [ "$1" = "install" ];then
	yum install -y epel-release
	rpm -Uvh ${rpm_uri}
	yum groupinstall -y "Development tools"
	yum install -y wget make gcc readline-devel perl pcre-devel openssl-devel git
	#############################	
	mkdir -p ${install_path}
	mkdir -p ${build_path}
	#############################	
	cd ${build_path}
	wget ${down_uri}
	tar zxvf openresty-${install_version}.tar.gz
	cd openresty-${install_version}
	###############################
	./configure --prefix=${install_path} --with-luajit
	gmake
	gmake install
	##############################
	cd ${install_path}
	git clone ${git_uri} openstar
	mv -f nginx/conf/nginx.conf nginx/conf/nginx.conf.bak
	#cp openstar/conf/nginx.conf nginx/conf/
	#cp openstar/conf/our.conf nginx/conf/
	#cp openstar/conf/waf.conf nginx/conf/
	ln -sf ${install_path}/openstar/conf/nginx.conf ${install_path}/nginx/conf/nginx.conf
	ln -sf ${install_path}/openstar/conf/waf.conf ${install_path}/nginx/conf/waf.conf
	ln -sf ${install_path}/openstar/conf/our.conf ${install_path}/nginx/conf/our.conf
	chown nobody:nobody -R ${install_path}
	chown root:nobody nginx/sbin/nginx
	chmod 750 nginx/sbin/nginx
	chmod u+s nginx/sbin/nginx
	nginx/sbin/nginx

	##############################
	echo "PATH=${install_path}/nginx/sbin:\$PATH" >> /etc/profile
	export PATH

elif [ "$1" = "openstar" ]; then
	cd ${install_path}
	newstar=`date "+%G-%m-%d-%H-%M-%S"`
	mv -f openstar/ openstar.${newstar}/
	git clone ${git_uri} openstar
	chown nobody:nobody -R openstar/
	ln -sf ${install_path}/openstar/conf/nginx.conf ${install_path}/nginx/conf/nginx.conf
	ln -sf ${install_path}/openstar/conf/waf.conf ${install_path}/nginx/conf/waf.conf
	ln -sf ${install_path}/openstar/conf/our.conf ${install_path}/nginx/conf/our.conf
	######### 保持原来所有规则
	alias cp='cp'
	cp -Rf  ${install_path}/openstar.${newstar}/base.json ${install_path}/openstar/
	cp -Rf  ${install_path}/openstar.${newstar}/conf_json ${install_path}/openstar/
	alias cp='cp -i'
	#########

elif [ "$1" = "openresty" ]; then
	cd ${build_path}
	wget ${down_uri}
	tar zxvf openresty-${install_version}.tar.gz
	cd openresty-${install_version}
	###############################
	./configure --prefix=${install_path} --with-luajit
	gmake
	gmake install
	cd ${install_path}
	chown nobody:nobody -R ${install_path}
	chown root:nobody nginx/sbin/nginx
	chmod 750 nginx/sbin/nginx
    chmod u+s nginx/sbin/nginx

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
	