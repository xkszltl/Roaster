FROM ubuntu

SHELL ["/bin/bash", "-c"]

RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y apt-utils sudo \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        axel \ 
        bash-completion \ 
        bc \ 
        binutils \
        ccache \
        cmake \ 
        curl \
        g++{,-4,-5,-6,-7,-8} gdb \ 
        git{,-{extras,lfs}} \ 
        glances htop \ 
        'iputils-*' \
        lib{asan{0,2,3,4,5},tsan0,ubsan{0,1}} \
        lib{boost-all,gflags,google-glog,grpc++,gtest,hwloc,jemalloc,leveldb,lmdb,opencv,rocksdb,snappy,ssl}-dev \ 
        libpapi-dev papi-tools \ 
        libprotobuf-dev protobuf-compiler \ 
        llvm-7{,-tools} \
        ltrace \
        moreutils \ 
        mtr \
        ninja-build \ 
        parallel \ 
        pciutils \
        pybind11-dev \
        python3 \
        ruby \
        strace \
        tmux \ 
        usbutils \
        valgrind \
        vim \ 
        wget \
        xz-utils pxz \
    && parallel --will-cite < /dev/null \
    && truncate -s0 ~/.bash_history
