FROM openresty/openresty:1.13.6.2-1-xenial

MAINTAINER zoucaitou <zoucaitou@gmail.com>

ENV WAF_ROOT=/opt/openresty/openstar

RUN mkdir -p $WAF_ROOT

COPY . $WAF_ROOT

COPY conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

COPY conf/waf.conf /usr/local/openresty/nginx/conf/waf.conf

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
