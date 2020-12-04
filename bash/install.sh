#!/bin/bash

# bash 版本
version=1.0

build_path=/opt/down
install_path=/opt/openresty
mkdir -p ${build_path}
mkdir -p ${install_path}

install_or_version=1.17.8.2
#1.11.2.2 nginx 1.11.2 , 1.11.2.1 nginx 1.11.2 , 1.9.15.1 nginx 1.9.15
# 1.15.8.3 819a31fa6e9cc8c5aa4838384a9717a7
openresty_uri=https://openresty.org/download/openresty-${install_or_version}.tar.gz
openresty_md5=ae9cdb51cabe42b0e3f46313da003d51
down_openresty(){
    cd ${build_path}
    if [ ! -f "openresty-${install_or_version}.tar.gz" ]; then
        echo "openresty-${install_or_version}.tar.gz 文件不存在  需要下载！"
        wget ${openresty_uri} || (echo "${Error}wget openresty Error!!" && exit 1)
    else
        # 文件存在检查 md5
        or_now=`md5sum openresty-${install_or_version}.tar.gz|awk '{print $1}'`
        if [ "${or_now}" = "${openresty_md5}" ]; then
            echo "openresty-${install_or_version}.tar.gz md5 ok!"
        else
            echo "openresty-${install_or_version}.tar.gz 文件 md5 不正确"
            rm -rf openresty-${install_or_version}.tar.gz
            wget ${openresty_uri} || (echo "${Error}wget openresty Error!!" && exit 1)
        fi
    fi
}
openstar_uri=https://codeload.github.com/starjun/openstar/zip/master

# centos 6 = remi-release-6.rpm ; centos 7 = remi-release-7.rpm
rpm_uri=http://rpms.famillecollet.com/enterprise/remi-release-7.rpm

luarocks_version=3.2.1
luarocks_uri=http://luarocks.org/releases/luarocks-${luarocks_version}.tar.gz
luarocks_md5=236ea48b78ddb96ecbd33654a573bdb2
down_luarocks(){
    cd ${build_path}
    if [ ! -f "luarocks-${luarocks_version}.tar.gz" ]; then
        echo "luarocks-${luarocks_version}.tar.gz 文件不存在  需要下载！"
        wget ${luarocks_uri} || (echo "wget luarocks Error" && exit 1)
    else
        # 文件存在检查 md5
        luarocks_now=`md5sum luarocks-${luarocks_version}.tar.gz|awk '{print $1}'`
        if [ "${luarocks_now}" = "${luarocks_md5}" ]; then
            echo "luarocks-${luarocks_version}.tar.gz md5 ok!"
        else
            echo "luarocks-${luarocks_version}.tar.gz 文件 md5 不正确"
            rm -rf luarocks-${luarocks_version}.tar.gz && wget ${luarocks_uri} || (echo "wget luarocks Error" && exit 1)
        fi
    fi
}

purge_version=2.3
purge_uri=http://labs.frickle.com/files/ngx_cache_purge-${purge_version}.tar.gz
purge_md5=3d4ec04bbc16c3b555fa20392c1119d1
# 2.3 版本的 md5
down_purge(){
    cd ${build_path}
    if [ ! -f "ngx_cache_purge-${purge_version}.tar.gz" ]; then
        echo "ngx_cache_purge-${purge_version}.tar.gz 文件不存在  需要下载！"
        wget ${purge_uri} || (echo "wget purge Error" && exit 1)
    else
        # 文件存在检查 md5
        purge_now=`md5sum ngx_cache_purge-${purge_version}.tar.gz|awk '{print $1}'`
        if [ "${purge_now}" = "${purge_md5}" ]; then
            echo "ngx_cache_purge-${purge_version}.tar.gz md5 ok!"
        else
            echo "ngx_cache_purge-${purge_version}.tar.gz 文件 md5 不正确"
            rm -rf ngx_cache_purge-${purge_version}.tar.gz && wget ${purge_uri} || (echo "wget purge Error" && exit 1)
        fi
    fi
}

function YUM_start(){
    yum install -y htop goaccess epel-release
    rpm -Uvh ${rpm_uri}
    yum groupinstall -y "Development tools"
    yum install -y sysstat wget make gcc readline-devel perl pcre-devel openssl-devel git unzip zip libmaxminddb-devel
}

function openstar(){
    cd ${install_path}
    wget -O openstar.zip ${openstar_uri}
    unzip -o openstar.zip

    alias mv='mv'
    mv -f openstar-master openstar
    alias mv='mv -i'

    chown nobody:nobody -R openstar
    ln -sf ${install_path}/openstar/conf/nginx.conf ${install_path}/nginx/conf/nginx.conf
    ln -sf ${install_path}/openstar/conf/waf.conf ${install_path}/nginx/conf/waf.conf
    #ln -sf ${install_path}/openstar/conf/http.conf ${install_path}/nginx/conf/http.conf
}

#安装jemalloc最新版本
jemalloc_md5=3d41fbf006e6ebffd489bdb304d009ae
jemalloc_url=https://github.com/jemalloc/jemalloc/releases/download/5.2.1/jemalloc-5.2.1.tar.bz2
jemalloc_install(){
    if [[ -f /usr/local/lib/libjemalloc.so ]]; then
        echo "jemalloc install" && return
    fi
    cd ${build_path}
    if [ ! -f "jemalloc-5.2.1.tar.bz2" ]; then
        echo "jemalloc-5.2.1.tar.bz2 文件不存在 需要下载！"
        wget ${jemalloc_url} || (echo "${Error}wget jemalloc Error" && exit 1)
    else
        # 文件存在检查 md5
        jemalloc_now=`md5sum jemalloc-5.2.1.tar.bz2|awk '{print $1}'`
        if [ "${jemalloc_now}" = "${jemalloc_md5}" ]; then
            echo "jemalloc-5.2.1.tar.bz2 md5 ok!"
        else
            echo "jemalloc-5.2.1.tar.bz2 文件 md5 不正确"
            rm -rf jemalloc-5.2.1.tar.bz2
            wget ${jemalloc_url} || (echo "${Error}wget jemalloc Error" && exit 1)
        fi
    fi
    rm -rf jemalloc-5.2.1
    tar -xvf jemalloc-5.2.1.tar.bz2 || (echo "${Error}tar -xvf jemalloc-xxx.tar.bz2 Error" && exit 1)
    cd jemalloc-5.2.1
    ./configure || (echo "${Error}configure jemalloc Error" && exit 1)
    make && make install
    echo '/usr/local/lib' > /etc/ld.so.conf.d/local.conf
    ldconfig
}

luarocks_install(){
    if [[ ! -f ${install_path}/luarocks/bin/luarocks ]]; then
        down_luarocks
        cd ${build_path}
        rm -rf luarocks-${luarocks_version} && tar xvzf luarocks-${luarocks_version}.tar.gz
        cd luarocks-${luarocks_version}
        ./configure --prefix=${install_path}/luarocks \
                    --with-lua=${install_path}/luajit/ \
                    --with-lua-include=${install_path}/luajit/include/luajit-2.1 \
                    --lua-suffix='jit' || (echo "configure luarocks Error" && exit 1)
        make
        make install
        # ln -sf ${install_path}/luarocks/bin/luarocks /usr/bin/luarocks
    fi
    echo "luarocks install"
}

function openresty(){
    jemalloc_install
    down_openresty
    cd ${build_path}
    rm -rf openresty-${install_or_version} && tar zxvf openresty-${install_or_version}.tar.gz
    git clone --depth=1 https://github.com/leev/ngx_http_geoip2_module.git || (echo "git clone ngx_http_geoip2_module Error" && exit 1)
    git clone --depth=1 https://github.com/api7/lua-var-nginx-module.git || (echo "git clone lua-var-nginx-module Error" && exit 1)
    git clone --depth=1 https://github.com/vozlt/nginx-module-vts.git || (echo "git clone nginx-module-vts Error" && exit 1)
    # ngx_cache_purge 检查下载
    down_purge
    rm -rf ngx_cache_purge-${purge_version}
    tar zxf ngx_cache_purge-${purge_version}.tar.gz || (echo "${Error}tar -xvf ngx_cache_purge-${purge_version}.tar.gz Error" && exit 1)
    cd openresty-${install_or_version}
    ./configure --prefix=${install_path} \
                --add-module=${build_path}/ngx_http_geoip2_module \
                --add-module=${build_path}/nginx-module-vts \
                --add-module=${build_path}/ngx_cache_purge-${purge_version} \
                --with-http_stub_status_module \
                --with-http_realip_module \
                --with-http_v2_module \
                --with-ld-opt='-ljemalloc' || (echo "configure openresty Error!!" && exit 1)
    gmake
    gmake install

    chown nobody:nobody -R ${install_path}
    cd ${install_path}
    chown root:nobody nginx/sbin/nginx
    chmod 751 nginx/sbin/nginx
    chmod u+s nginx/sbin/nginx
}

function echo_ServerMsg(){
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
    echo "./install.sh install/openstar/openresty/check"
}

function check(){
    mkdir -p ${install_path}/nginx/conf/conf.d
    chown nobody:nobody -R ${install_path}
    chown root:nobody ${install_path}/nginx/sbin/nginx
    chmod 751 ${install_path}/nginx/sbin/nginx
    chmod u+s ${install_path}/nginx/sbin/nginx
    ln -sf ${install_path}/openstar/conf/nginx.conf ${install_path}/nginx/conf/nginx.conf
    ln -sf ${install_path}/openstar/conf/waf.conf ${install_path}/nginx/conf/waf.conf
    cd ${install_path}/nginx/html && (ls |grep "favicon.ico" || wget https://www.nginx.org/favicon.ico)
    echo "check Done~!"
}

##############################
if [ "$1" = "install" ];then
    YUM_start

    openresty

    openstar

    ##############################
    cat /etc/profile |grep "openresty" ||(echo "PATH=${install_path}/nginx/sbin:\$PATH" >> /etc/profile && export PATH)

elif [ "$1" = "openstar" ]; then
    cd ${install_path}
    newstar=`date "+%G-%m-%d-%H-%M-%S"`
    alias mv='mv'
    mv -f openstar/ openstar.${newstar}/
    alias mv='mv -i'
    openstar

    ######### 保持原来所有规则
    alias cp='cp'
    cp -Rf  ${install_path}/openstar/conf_json ${install_path}/openstar/conf_json_bak
    cp -Rf  ${install_path}/openstar.${newstar}/conf_json ${install_path}/openstar/
    chown -R nobody:nobody ${install_path}/openstar/
    alias cp='cp -i'
    #########

elif [ "$1" = "openresty" ]; then

    openresty
    cat /etc/profile |grep "openresty" ||(echo "PATH=${install_path}/nginx/sbin:\$PATH" >> /etc/profile && export PATH)
elif [ "$1" = "check" ]; then

    check
    cat /etc/profile |grep "openresty" ||(echo "PATH=${install_path}/nginx/sbin:\$PATH" >> /etc/profile && export PATH)
elif [[ "$1" = "luarocks" ]]; then
    luarocks_install

else
    echo_ServerMsg
fi
