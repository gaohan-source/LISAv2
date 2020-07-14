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

# Function Timeout().
# Avoiding the nginx tests timeout and stuck.
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

drive_name=$(bash get_data_disk_dev_name.sh)
LogMsg "Disk used: $drive_name"

case $DISTRO in
    "suse"*)
        suse_packages=(git-core db48-utils libaio-devel libattr1 \
            libcap-progs libdb-4_8 perl-BerkeleyDB)
        install_package "${suse_packages[@]}"
        ;;
    "ubuntu"* | "debian"*)
        deb_packages=(git libaio-dev libattr1 libcap-dev keyutils \
            libdb4.8 libberkeleydb-perl expect dh-autoreconf gdb \
            libnuma-dev quota genisoimage db-util unzip exfat-utils)
        install_package "${deb_packages[@]}"
        ;;
    "redhat"* | "centos"* | "fedora"*)
		rpm_packages=(git libaio-devel libattr libcap-devel libdb)
		# this must be revised later once epel_8 is available
		if [[ $DISTRO != redhat_8 ]]; then
			rpm_packages+=(db4-utils)
		fi
		install_epel
        install_package "${rpm_packages[@]}"
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

cd /home/lisa/;
rm -Rf nginx
rm -Rf nginx-tests

git clone --depth 1 https://github.com/nginx/nginx.git
git clone --depth 1 https://github.com/nginx/nginx-tests.git

# compile and install the nginx via the config.test
cd $SCRIPTPATH;

cp nginx-config.sh /home/lisa/;
cd /home/lisa/;
chmod +x nginx-config.sh ;

#run the test
Timeout ;
cd $SCRIPTPATH;
RESULT1=$(tail -1  $SCRIPTPATH/nginx-test.log | grep "FAIL" | wc -l)
if (( $RESULT1 ))
then
        echo -e "Nginx Official Test RESULT:FAIL"
else
        echo -e "Nginx Official Test RESULT:PASS"
fi

collect_VM_properties
SetTestStateCompleted
exit 0;