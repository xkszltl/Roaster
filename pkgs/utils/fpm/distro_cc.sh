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
'ubuntu-22.'* | 'ubuntu-23.'*)
    # Ubuntu 22.04 has GCC 12 but CUDA 11.8 only supports up to GCC 11.
    export CC="gcc-11" CXX="g++-11" FC="gfortran-11" AR='gcc-ar-11' RANLIB='gcc-ranlib-11'
    ;;
*)
    export CC="gcc" CXX="g++" GC="gfortran" AR='gcc-ar' RANLIB='gcc-ranlib'
    ;;
esac
