#!/bin/bash

set -e

case "$DISTRO_ID-$DISTRO_VERSION_ID" in
centos-* | fedora-* | rhel-*)
    set +xe
    . scl_source enable devtoolset-9 || exit 1
    set -xe
    export CC="gcc" CXX="g++"
    ;;
debian-10)
    export CC="gcc-8" CXX="g++-8"
    ;;
debian-11)
    export CC="gcc-10" CXX="g++-10"
    ;;
ubuntu-18.* | ubuntu-19.*)
    export CC="gcc-8" CXX="g++-8"
    ;;
ubuntu-20.* | ubuntu-21.*)
    export CC="gcc-10" CXX="g++-10"
    ;;
*)
    export CC="gcc" CXX="g++"
    ;;
esac
