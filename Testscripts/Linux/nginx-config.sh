#!/bin/bash
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.

# if [ ! -d "$NGINX_INSTALL_DIR" ]; then
#    echo "NGINX install directory not been set or does not exist. Run:- export NGINX_INSTALL_DIR=<location you want to install the built nginx server to>\n"
#    exit 0
# fi

# if [ ! -d "https://github.com/nginx/nginx.git" ]; then
#    echo "NGINX_SRC_DIR has not been set or does not exist. Run:- export NGINX_SRC_DIR=<location the nginx source code directory in>\n"
#    exit 0
# fi

./configure \
--prefix=/home/lisa/ \
--user=root \
--group=root \
--with-file-aio \
--with-ipv6 \
--with-http_realip_module \
--with-http_addition_module \
--with-http_xslt_module \
--with-http_image_filter_module \
--with-http_geoip_module \
--with-http_sub_module \
--with-http_dav_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gzip_static_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_degradation_module \
--with-http_stub_status_module \
--with-http_perl_module \
--with-http_auth_request_module \
--with-mail \
--with-mail_ssl_module \
--with-debug \
--with-http_gunzip_module \
--with-http_ssl_module \
--with-http_v2_module \
--with-http_slice_module \
--with-stream \
--with-stream_ssl_module \
--with-stream_ssl_preread_module \

./auto/configure \
--with-http_ssl_module \
--with-http_slice_module \
--with-pcre-jit \
--with-threads \
--with-http_v2_module \
--without-http_fastcgi_module \
--without-http_grpc_module \
--without-http_uwsgi_module \
--without-http_scgi_module \
--without-http_memcached_module
