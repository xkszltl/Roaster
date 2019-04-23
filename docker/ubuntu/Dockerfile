FROM ubuntu

SHELL ["/bin/bash", "-c"]

RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y apt-utils \
    && apt-get install -y \
        bash-completion \ 
        cmake \ 
        g++{,-4,-5,-6,-7,-8} \ 
        git{,-{extras,lfs}} \ 
        glances htop \ 
        lib{boost-all,hwloc,leveldb,lmdb,opencv,rocksdb,ssl}-dev \ 
        libpapi-dev papi-tools \ 
        llvm-7{,-tools} \
        moreutils \ 
        ninja-build \ 
        parallel \ 
        tmux \ 
        vim \ 
        xz-utils pxz \ 
    && parallel --will-cite < /dev/null \
    && touch -s0 ~/.bash_history
