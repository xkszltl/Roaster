#!/bin/bash

set -e

export HTTP_PROXY=proxy.codingcafe.org:8118
[ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
[ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
[ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY

export ROOT=/var/mirrors

mkdir -p $ROOT
cd $_

parallel -j 8 --line-buffer --bar 'bash -c '"'"'
set -e
[ $(xargs -n1 <<<{} | wc -l) -ne 2 ] && exit 0
export SRC_SITE=$(xargs -n1 <<<{} 2>/dev/null | head -n1)
export SRC_DIR=$(xargs -n1 <<<{} 2>/dev/null | tail -n1)
export SRC=$SRC_SITE$SRC_DIR.git
export DST_SITE=git@git.codingcafe.org:Mirrors/
export DST_DIR=$SRC_DIR
export DST=$DST_SITE$DST_DIR.git
export LOCAL=$(pwd)/$DST_DIR.git
if [ -d $LOCAL ]; then
	cd $LOCAL && git fetch --all
else
	mkdir -p $(dirname $LOCAL) && cd $(dirname $LOCAL) && git clone --mirror $SRC && cd $LOCAL
fi &&
git remote set-url --push origin $DST && git push --mirror
'"'" ::: {\
https://github.com/\ {\
aws/aws-{cli,sdk-{cpp,go,java,js,net,php,ruby}},\
BVLC/caffe,\
caffe2/{caffe2,models},\
facebook/rocksdb,\
gflags/gflags,\
google/{benchmark,snappy,glog,googletest,leveldb,protobuf},\
jemalloc/jemalloc,\
Kitware/{CMake,VTK},\
llvm-mirror/{ll{vm,d,db,go},clang{,-tools-extra},polly,compiler-rt,openmp,lib{unwind,cxx{,abi}},test-suite},\
LMDB/lmdb,\
Maratyszcza/{confu,FP16,FXdiv,NNPACK,PeachPy,psimd,pthreadpool},\
NervanaSystems/{neon,nervanagpu},\
NVIDIA/{DIGITS,cnmem,libglvnd,nccl,nvidia-docker},\
NVLabs/{cub,xmp},\
open-mpi/ompi,\
opencv/opencv,\
SchedMD/slurm,\
shadowsocks/{ShadowsocksX-NG,libQtShadowsocks,shadowsocks{,-go,-libev,-manager,-windows}},\
tensorflow/tensorflow,\
xianyi/OpenBLAS,\
},\
https://gitlab.com/\ {\
NVIDIA/cuda,\
},\
}
