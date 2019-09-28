#!/bin/bash

set -e

date

# export HTTP_PROXY=proxy.codingcafe.org:8118
[ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
[ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
[ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY

export ROOT=/var/mirrors

mkdir -p $ROOT
cd $_

[ $# -ge 1 ] && export PATTERN="$1"

parallel --bar --group --shuf -j 10 'bash -c '"'"'
set -e
export ARGS={}"  "
xargs -n1 <<< "$ARGS"
[ $(xargs -n1 <<< {} | wc -l) -ne 3 ] && exit 0
export SRC_SITE="$(cut -d" " -f1 <<< "$ARGS")"
export SRC_DIR="$(cut -d" " -f3 <<< "$ARGS")"
export SRC="$SRC_SITE$SRC_DIR.git"
export DST_DOMAIN="$(cut -d" " -f2 <<< "$ARGS" | sed "s/^\/*//" | sed "s/\/*$//")"
export DST_SITE="git@git.codingcafe.org:Mirrors/$DST_DOMAIN"
export DST_DIR="$SRC_DIR"
export DST="$DST_SITE$DST_DIR.git"
export LOCAL="$(pwd)/$DST_DIR.git"

echo "[\"$DST_DIR\"]"

if [ ! "'"$PATTERN"'" ] || grep "'"$PATTERN"'" <<< "$SRC_DIR"; then
    mkdir -p "$(dirname "$LOCAL")"
    cd "$(dirname "$LOCAL")"
    [ -d "$LOCAL" ] || git clone --mirror "$DST" "$LOCAL" 2>&1 || git clone --mirror "$SRC" "$LOCAL" 2>&1
    cd "$LOCAL"
    git remote set-url origin "$DST" 2>&1
    git fetch --all 2>&1 || true
    [ "$(git lfs ls-files)" ] && git lfs fetch --all 2>&1 || true
    git remote set-url origin "$SRC" 2>&1
    git fetch --prune --all 2>&1
    # [ "$(git lfs ls-files)" ] && git lfs fetch --prune --all 2>&1
    [ "$(git lfs ls-files)" ] && git lfs fetch --all 2>&1
    git gc --auto 2>&1
    git remote set-url origin "$DST" 2>&1
    [ "$(git lfs ls-files)" ] && git lfs push --all origin 2>&1 || true
    git push --mirror origin 2>&1
fi
'"'" ::: {\
https://github.com/\ /\ {\
01org/{mkl-dnn,processor-trace,tbb},\
abseil/abseil-{cpp,py},\
agauniyal/{rang,termdb},\
aquynh/capstone,\
ARM-software/{arm-trusted-firmware,ComputeLibrary,lisa},\
asmjit/{asm{db,jit,tk},cult},\
aws/aws-{cli,sdk-{cpp,go,java,js,net,php,ruby}},\
axel-download-accelerator/axel,\
benjaminp/six,\
boostorg/boost,\
BVLC/caffe,\
c-ares/c-ares,\
caffe2/{caffe2,models},\
catchorg/{Catch2,Clara},\
ccache/ccache,\
cocodataset/{cocoapi,panopticapi},\
containerd/containerd,\
cython/cython,\
dmlc/{dlpack,dmlc-core,gluon-cv,gluon-nlp,HalideIR,tvm,xgboost},\
docker/docker-ce,\
dotnet/{cli,core{,-setup,clr,fx},standard},\
eigenteam/eigen-git-mirror,\
emil-e/rapidcheck,\
envoyproxy/{data-plane-api,envoy,{go,java}-control-plane,nighthawk,protoc-gen-validate},\
facebook/{rocksdb,zstd},\
facebookincubator/gloo,\
facebookresearch/{Detectron,fastText},\
FFmpeg/FFmpeg,\
frerich/clcache,\
Frozenball/pytest-sugar,\
gabime/spdlog,\
gflags/gflags,\
giampaolo/psutil,\
github/{git-lfs,gitignore},\
goldmann/docker-squash,\
google/{benchmark,bloaty,boringssl,flatbuffers,gemmlowp,glog,googletest,leveldb,nsync,protobuf,re2,skia,snappy,upb},\
googleapis/googleapis,\
googlefonts/{fontmake,noto-{cjk,emoji,fonts,sans-hebrew,source},nototools,robotoslab},\
grpc/grpc{,-{dart,dotnet,go,java,node,php,proto,swift,web}},\
halide/Halide,\
harfbuzz/harfbuzz,\
houseroad/foxi,\
HowardHinnant/date,\
HypothesisWorks/hypothesis,\
intel/{ARM_NEON_2_x86_SSE,compute-runtime,ideep,mkl-dnn},\
intelxed/xed,\
IvanKobzarev/fbjni,\
JDAI-CV/{dabnn{,-example},DCL,DNNLibrary},\
jemalloc/jemalloc,\
jordansissel/fpm,\
Kitware/{CMake,VTK},\
lemire/simdjson,\
libav/libav,\
llvm-mirror/{ll{vm,d,db,go},clang{,-tools-extra},polly,compiler-rt,openmp,lib{unwind,cxx{,abi}},test-suite},\
LMDB/lmdb,\
lutzroeder/netron,\
madler/zlib,\
Maratyszcza/{confu,cpuinfo,FP16,FXdiv,NNPACK,PeachPy,psimd,pthreadpool},\
micheles/{decorator,plac},\
Microsoft/{dotnet,GSL,onnxruntime{,-tvm},Terminal,TypeScript,vcpkg,vscode,wil},\
moby/{buildkit,moby},\
mono/{libgdiplus,linker,mono{,-tools,develop,torrent}},\
nanopb/nanopb,\
NervanaSystems/{coach,distiller,neon,ngraph},\
networkx/networkx,\
nico/demumble,\
nicolargo/glances,\
ninja-build/ninja,\
numpy/numpy{,doc},\
NVIDIA/{DALI,DIGITS,cnmem,libglvnd,nccl,nccl-tests,nvidia-{container-runtime,docker,installer,modprobe,persistenced,settings,xconfig}},\
NVlabs/{cub,ffhq-dataset,pacnet,PWC-Net,SPADE,stylegan,xmp},\
onnx/{models,onnx{,-tensorrt,mltools},tutorials},\
open-mpi/ompi,\
open-source-parsers/jsoncpp,\
opencv/{ade,cvat,dldt,open_model_zoo,opencv{,_{3rdparty,contrib,extra}},openvino_training_extensions},\
openssl/openssl,\
openwrt/{luci,openwrt,packages,targets,telephony,video},\
PeachPy/enum34,\
protocolbuffers/{protobuf,upb},\
pybind/pybind11,\
PythonCharmers/python-future,\
python-pillow/{Pillow,pillow-perf,Sane},\
pypa/{pip,pipenv,setuptools,virtualenv,warehouse,wheel},\
pytest-dev/{pluggy,py,pytest},\
python/typing,\
python-attrs/attrs,\
pytorch/{cpuinfo,examples,FBGEMM,glow,ignite,pytorch,QNNPACK,tutorials,vision,xla},\
RadeonOpenCompute/{hcc,ROCm-Device-Libs,ROCR-Runtime},\
RMerl/{am-toolchains,asuswrt-merlin.ng},\
ROCm-Developer-Tools/HIP,\
SchedMD/slurm,\
scipy/scipy{,-mathjax,-sphinx-theme},\
shadowsocks/{ShadowsocksX-NG,libQtShadowsocks,shadowsocks{,-go,-libev,-manager,-windows}},\
shibatch/sleef,\
Tencent/rapidjson,\
tensorflow/{agents,datasets,docs,io,models,tensorboard,tensorflow,transform},\
torvalds/linux,\
uploadcare/pillow-simd,\
USCiLab/cereal,\
wjakob/clang-cindex-python3,\
xianyi/OpenBLAS,\
yaml/pyyaml,\
Yangqing/ios-cmake,\
zeromq/{cppzmq,libzmq,pyzmq},\
},\
https://gitlab.com/\ /\ {\
NVIDIA/cuda,\
},\
}

date
