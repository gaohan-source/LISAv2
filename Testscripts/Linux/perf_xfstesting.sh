#!/bin/bash

#######################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved.
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#        http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
#######################################################################

#######################################################################
#
# perf_xfstesting.sh
# Author : SHITAL SAVEKAR <v-shisav@microsoft.com>
#
# Description:
#       Download and run IPERF3 network performance tests.
#       This script needs to be run on client VM.
#
# Supported Distros:
#       Ubuntu 16.04
# Supported Filesystems : ext4, xfs

#######################################################################

while echo $1 | grep ^- > /dev/null; do
    eval $( echo $1 | sed 's/-//g' | tr -d '\012')=$2
    shift
    shift
done

XFSTestConfigFile="xfstests-config.config"
touch /root/XFSTestingConsole.log

LogMsg()
{
        echo `date "+%b %d %Y %T"` : "${1}"     # Add the time stamp to the log message
        echo "${1}" >> /root/XFSTestingConsole.log
}

InstallXFSTestTools()
{
    DISTRO=`grep -ihs "buntu\|Suse\|Fedora\|Debian\|CentOS\|Red Hat Enterprise Linux\|clear-linux-os" /etc/{issue,*release,*version} /usr/lib/os-release`
    if [[ $DISTRO =~ "Ubuntu" ]] || [[ $DISTRO =~ "Debian" ]];
    then
        LogMsg "Detected Ubuntu/Debian. Installing required packages..."
        until dpkg --force-all --configure -a; sleep 10; do echo 'Trying again...'; done
        apt-get update
        apt-get -y install gcc xfslibs-dev uuid-dev libtool xfsprogs e2fsprogs automake libuuid1 libuuidm-ocaml-dev attr libattr1-dev libacl1-dev libaio-dev  gawk xfsprogs libgdbm-dev quota fio dbench bc make dos2unix
        git clone git://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git
        mv xfstests-dev xfstests
        cd xfstests
        ./configure
        make
        cd ..
        LogMsg "Packages installation complete."
    else
        LogMsg "Unknown Distro"
        exit 10
    fi
}

if [ -e ${XFSTestConfigFile} ]; then
	LogMsg "${XFSTestConfigFile} File is present."
else
    errMsg="Error: missing ${XFSTestConfigFile} file"
    LogMsg "${errMsg}"
    exit 10
fi

#Configure XFS Tools
InstallXFSTestTools

dos2unix ${XFSTestConfigFile}
cp -f ${XFSTestConfigFile} ./xfstests/local.config

mkdir -p /root/ext4
mkdir -p /root/xfs

#RunTests
if [[ $TestFileSystem == "cifs" ]];
then
    mkdir -p /test1
    cd xfstests
    #Download Exclusion files
    wget https://wiki.samba.org/images/d/db/Xfstests.exclude.very-slow.txt -O tests/cifs/exclude.very-slow
    wget https://wiki.samba.org/images/b/b0/Xfstests.exclude.incompatible-smb3.txt -O tests/cifs/exclude.incompatible-smb3

    ./check -s $TestFileSystem -E tests/cifs/exclude.incompatible-smb3 -E tests/cifs/exclude.very-slow >> /root/XFSTestingConsole.log
    cd ..
elif [[ $TestFileSystem == "ext4" ]] || [[ $TestFileSystem == "xfs" ]];
then
    LogMsg "Formatting /dev/sdc with ${TestFileSystem}"
    if [[ $TestFileSystem == "xfs" ]];
    then
        mkfs.xfs -f /dev/sdc
    else
        echo y | mkfs -t $TestFileSystem /dev/sdc
    fi
    mkdir -p /test2
    cd xfstests
    LogMsg "Runnint tests for $TestFileSystem file system"
    ./check -s $TestFileSystem >> /root/XFSTestingConsole.log
    cd ..
else
    LogMsg "$TestFileSystem is not supported."
fi
LogMsg "TestCompleted"