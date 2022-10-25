#!/bin/bash

set -e

case "$DISTRO_ID-$DISTRO_VERSION_ID" in
'centos-'* | 'fedora-'* | 'rhel-'* | 'scientific-'*)
    set +xe
    . scl_source enable devtoolset-11 || exit 1
    set -xe
    export CC="gcc" CXX="g++" FC="gfortran" AR='gcc-ar' RANLIB='gcc-ranlib'
    ;;
'debian-10' | 'ubuntu-18.'* | 'ubuntu-19.'*)
    export CC="gcc-8" CXX="g++-8" FC="gfortran-8" AR='gcc-ar-8' RANLIB='gcc-ranlib-8'
    ;;
'debian-11' | 'ubuntu-20.'* | 'ubuntu-21.'*)
    export CC="gcc-10" CXX="g++-10" FC="gfortran-10" AR='gcc-ar-10' RANLIB='gcc-ranlib-10'
    ;;
'ubuntu-22.'*)
    export CC="gcc-12" CXX="g++-12" FC="gfortran-12" AR='gcc-ar-12' RANLIB='gcc-ranlib-12'
    ;;
*)
    export CC="gcc" CXX="g++" GC="gfortran" AR='gcc-ar' RANLIB='gcc-ranlib'
    ;;
esac
