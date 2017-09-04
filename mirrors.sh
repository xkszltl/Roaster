#!/bin/bash

set -e

export http_proxy=127.0.0.1:8118
export HTTP_PROXY=$http_proxy
export https_proxy=$http_proxy
export HTTPS_PROXY=$https_proxy

mkdir -p /var/mirrors
cd /var/mirrors
parallel -j 10 --ungroup 'bash -c '"'"'
set -e
export ROOT=/var/mirrors
if [ ! -d $ROOT/{} ]; then mkdir -p $ROOT/$(dirname {}) && cd $ROOT/$(dirname {}) && git clone --mirror git@github.com:{} && cd $ROOT/{}
else cd $ROOT/{} && git fetch --all
fi &&
git remote set-url --push origin git@git.codingcafe.org:Mirrors/{} && git push --mirror
'"'" ::: {\
aws/aws-{cli,sdk-{cpp,go,java,js,net,php,ruby}},\
BVLC/caffe,\
caffe2/{caffe2,models},\
gflags/gflags,\
google/{benchmark,snappy,glog,googletest,leveldb,protobuf},\
jemalloc/jemalloc,\
llvm-mirror/{ll{vm,d,db,go},clang{,-tools-extra},polly,compiler-rt,openmp,lib{unwind,cxx{,abi}},test-suite},\
Maratyszcza/{FP16,FXdiv,NNPACK,confu,psimd,pthreadpool},\
NervanaSystems/{neon,nervanagpu},\
NVIDIA/{DIGITS,cnmem,libglvnd,nccl,nvidia-docker},\
NVLabs/{cub,xmp},\
shadowsocks/{ShadowsocksX-NG,libQtShadowsocks,shadowsocks{,-go,-libev,-manager,-windows}}\
}.git
