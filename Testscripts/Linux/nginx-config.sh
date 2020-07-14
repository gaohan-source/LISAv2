#!/bin/bash
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.

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
