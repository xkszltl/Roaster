#!/bin/bash

set -e

export HTTP_PROXY=proxy.codingcafe.org:8118
[ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
[ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
[ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY

export ROOT=/var/mirrors

mkdir -p $ROOT
cd $_

[ $# -ge 1 ] && export PATTERN=$1

parallel --bar --group -j 10 'bash -c '"'"'
set -e
[ $(xargs -n1 <<<{} | wc -l) -ne 2 ] && exit 0
export SRC_SITE=$(xargs -n1 <<<{} 2>/dev/null | head -n1)
export SRC_DIR=$(xargs -n1 <<<{} 2>/dev/null | tail -n1)
export SRC=$SRC_SITE$SRC_DIR.git
export DST_SITE=git@git.codingcafe.org:Mirrors/
export DST_DIR=$SRC_DIR
export DST=$DST_SITE$DST_DIR.git
export LOCAL=$(pwd)/$DST_DIR.git

echo "[\"$DST_DIR\"]"

if [ ! '"$PATTERN"' ] || grep '"$PATTERN"' <<<$SRC_DIR; then
    mkdir -p $(dirname $LOCAL)
    cd $(dirname $LOCAL)
    [ -d $LOCAL ] || git clone --mirror $SRC "$LOCAL" 2>&1 || git clone --mirror "$SRC" "$LOCAL" 2>&1
    cd $LOCAL
    git remote set-url origin $DST 2>&1
    git fetch --all 2>&1 || true
    if [ $(git lfs ls-files | wc -l) -gt 0 ]; then
        git lfs fetch --all 2>&1 || true
    fi
    git remote set-url origin $SRC 2>&1
    git fetch --prune --all 2>&1
    if [ $(git lfs ls-files | wc -l) -gt 0 ]; then
        git lfs fetch --prune --all 2>&1
    fi
    git gc --auto 2>&1
    git remote set-url origin $DST 2>&1
    if [ $(git lfs ls-files | wc -l) -gt 0 ]; then
        git lfs push --all origin 2>&1 || true
    fi
    git push --mirror origin 2>&1
fi
'"'" ::: {\
https://github.com/\ {\
01org/{processor-trace,tbb},\
ARM-software/{arm-trusted-firmware,ComputeLibrary,lisa},\
aws/aws-{cli,sdk-{cpp,go,java,js,net,php,ruby}},\
boostorg/boost,\
BVLC/caffe,\
caffe2/{caffe2,models},\
catchorg/{Catch2,Clara},\
ccache/ccache,\
cython/cython,\
eigenteam/eigen-git-mirror,\
facebook/{rocksdb,zstd},\
facebookincubator/gloo,\
facebookresearch/{Detectron,fastText},\
gflags/gflags,\
github/gitignore,\
google/{benchmark,snappy,glog,googletest,leveldb,protobuf},\
halide/Halide,\
intel/{ideep,mkl-dnn},\
jemalloc/jemalloc,\
jordansissel/fpm,\
Kitware/{CMake,VTK},\
llvm-mirror/{ll{vm,d,db,go},clang{,-tools-extra},polly,compiler-rt,openmp,lib{unwind,cxx{,abi}},test-suite},\
LMDB/lmdb,\
Maratyszcza/{confu,cpuinfo,FP16,FXdiv,NNPACK,PeachPy,psimd,pthreadpool},\
NervanaSystems/{neon,nervanagpu},\
nanopb/nanopb,\
ninja-build/ninja,\
numpy/numpy{,doc},\
NVIDIA/{DIGITS,cnmem,libglvnd,nccl,nvidia-docker},\
NVLabs/{cub,xmp},\
onnx/{models,onnx{,-tensorrt,mltools},tutorials},\
open-mpi/ompi,\
opencv/opencv,\
pybind/pybind11,\
pytest-dev/{py,pytest},\
pytorch/{examples,pytorch,tutorials},\
RMerl/{am-toolchains,asuswrt-merlin.ng},\
SchedMD/slurm,\
scipy/scipy{,-mathjax,-sphinx-theme},\
shadowsocks/{ShadowsocksX-NG,libQtShadowsocks,shadowsocks{,-go,-libev,-manager,-windows}},\
tensorflow/tensorflow,\
USCiLab/cereal,\
xianyi/OpenBLAS,\
zeromq/{cppzmq,libzmq,pyzmq},\
},\
https://gitlab.com/\ {\
NVIDIA/cuda,\
},\
}
