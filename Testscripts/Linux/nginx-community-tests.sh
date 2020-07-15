#!/bin/bash
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.

###############################################################################
#
# Description:
# For the nginx test,the packages installed by yum
#   cpan hg pcre geoip perl-Geo-IP.x86_64
#   GeoIP-devel.x86_64 memcached perl-FCGI.x86_64
#   perl-GDGraph.noarch perl-ExtUtils-Embed.noarch
#
# For the nginx test,the perl packages installed
#   Test::Nginx Protocol::WebSocket
#   IO::Socket::SSL Cache::Memcached
#   Cache::Memcached::Fast
#
###############################################################################

# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    echo "TestAborted" > state.txt
    exit 0
}

# Source constants file and initialize most common variables
UtilsInit

# Checks what Linux distro we are running on
GetDistro
update_repos

LogMsg "Installing dependencies"
common_packages=(m4 bison flex make gcc psmisc autoconf automake)

update_repos
install_package "${common_packages[@]}"

case $DISTRO in
    "ubuntu"*)
        deb_packages=(git libaio-dev libattr1 libcap-dev keyutils \
            libdb4.8 libberkeleydb-perl expect dh-autoreconf gdb \
            libnuma-dev quota genisoimage db-util unzip exfat-utils)
        install_package "${deb_packages[@]}"
        ;;
    *)
        LogMsg "Unknown distro $DISTRO, continuing to try for RPM installation"
        ;;
esac

Timeout()
{
    waitfor=3600
    TEST_NGINX_BINARY=/home/lisa/nginx prove . >$SCRIPTPATH/nginx-test.log &
    commandpid=$!

    ( sleep $waitfor ; kill -9 $commandpid  > /dev/null 2>&1 ) &
    sleeppid=$PPID

    wait $commandpid > /dev/null 2>&1
    kill $sleeppid > /dev/null 2>&1
    return 0
}

#pre-set the env
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
nginx_git_url="https://github.com/nginx/nginx.git"
nginxtest_git_url="https://github.com/nginx/nginx-tests.git"

cd /home/lisa/;
rm -Rf nginx
rm -Rf nginx-tests

git clone --depth 1 nginx_git_url
git clone --depth 1 nginxtest_git_url

# compile and install the nginx via the config.test
cd $SCRIPTPATH;

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

#run the test
Timeout ;
cd $SCRIPTPATH;
Result1=$(tail -1  $SCRIPTPATH/nginx-test.log | grep "FAIL" | wc -l)
if (( $Result1 ))
then
        echo -e "Nginx Official Test RESULT:FAIL"
        SetTestStateFailed() 
else
        echo -e "Nginx Official Test RESULT:PASS"
        SetTestStatePass() 
fi

SetTestStateCompleted
exit 0;