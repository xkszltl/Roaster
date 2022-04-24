#!/bin/bash

set +x
set -e

cd "$(dirname "$0")"

[ ! -e '/etc/os-release' ] || . <(sed 's/^\(..*\)/export DISTRO_\1/' '/etc/os-release')

echo 'Highlights:'
echo '- ...'
echo
echo 'Docker collection:'
echo '- ...'
echo
echo 'Size:'
echo '- CentOS: ...'
echo '- Debian: ...'
echo '- Ubuntu: ...'
echo
echo 'Roaster packages:'
echo '```'
case "$DISTRO_ID" in
"centos" | "fedora" | "rhel")
    rpm -qa 'roaster-*' | sort
    ;;
"debian" | "linuxmint" | "ubuntu")
    dpkg -l 'roaster-*' | grep '^ii' | sed 's/  */ /g' | cut -d' ' -f2,3
    ;;
esac
echo '```'
echo
echo 'Nvidia packages:'
echo '```'
case "$DISTRO_ID" in
"centos" | "fedora" | "rhel")
    rpm -qa 'cuda*' | sort
    rpm -qa 'libcudnn*' | sort
    rpm -qa 'libnvinfer*' | sort
    rpm -qa 'libnccl*' | sort
    ;;
"debian" | "linuxmint" | "ubuntu")
    dpkg -l {cuda,lib{cudnn,nvinfer,nccl}}'*' | grep '^ii' | sed 's/  */ /g' | cut -d' ' -f2,3
    ;;
esac
echo '```'
echo
