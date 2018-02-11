#!/bin/bash

set -e
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# ================================================================
# Environment Configuration
# ================================================================

export IS_CONTAINER=$([ -e /proc/1/cgroup ] && [ $(sed -n 's/^[^:]*:[^:]*:\(..\)/\1/p' /proc/1/cgroup | wc -l) -gt 0 ] && echo true || echo false)

# ----------------------------------------------------------------

export ROOT_DIR=$(cd $(dirname $0) && pwd)
if $IS_CONTAINER || [ ! -d /media/Scratch ]; then
    export SCRATCH=/tmp/scratch
else
    export SCRATCH=$(mktemp -p /media/Scratch)
fi
export STAGE=/etc/codingcafe/stage

export RPM_CACHE_REPO=/etc/yum.repos.d/cache.repo

# ================================================================
# Infomation
# ================================================================

echo '================================================================'
date
echo '----------------------------------------------------------------'
echo '                  CodingCafe CentOS Deployment                  '
$IS_CONTAINER && \
echo '                       -- In Container --                       '
echo '----------------------------------------------------------------'
echo -n '| Node     | '
uname -no
echo -n '| Kernel   | '
uname -sr
echo -n '| Platform | '
uname -m
echo    '| GPU      | '
which nvidia-smi 2>/dev/null >/dev/null && nvidia-smi -L | sed 's/^/|    ******| /'
echo '----------------------------------------------------------------'
df -h --sync --output=target,fstype,size,used,avail,pcent,source | sed 's/^/| /'
echo '================================================================'
echo
echo

# ================================================================
# Configure Scratch Directory
# ================================================================

rm -rvf $SCRATCH
mkdir -p $SCRATCH
# $IS_CONTAINER || mount -t tmpfs -o size=100% tmpfs $SCRATCH
cd $SCRATCH

# ================================================================
# Initialize Setup Stage
# ================================================================

[ -d $STAGE ] && [ $# -eq 0 ] || ( set -e
    rm -rvf $STAGE
    mkdir -p $(dirname $STAGE)/.$(basename $STAGE)
    cd $_
    [ $# -gt 0 ] && touch $@ || touch repo font pkg-{skip,all} intel auth ompi cuda slurm nagios ss tex cmake llvm-{gcc,clang} boost jemalloc openblas opencv gflags glog protobuf leveldb rocksdb lmdb caffe caffe2
    sync || true
    cd $SCRATCH
    mv -vf $(dirname $STAGE)/.$(basename $STAGE) $STAGE
)

for i in $(echo "
    repo
    env-pkg
    env-mirror
    font
    pkg
    cmake
    intel
    openmpi
    cuda
    auth
    slurm
    nagios
    shadowsocks
    texlive
    llvm
    boost
    jemalloc
    openblas
    opencv
    gflags
    glog
    protobuf
    leveldb
    rocksdb
    lmdb
    caffe
    caffe2
"); do
    . $ROOT_DIR/pkgs/$i.sh
done

# ================================================================
# Cleanup
# ================================================================

cd

ldconfig &
rm -rvf $SCRATCH &

if $IS_CONTAINER; then
    which ccache 2>/dev/null >/dev/null && ccache -C &
    yum autoremove -y && yum clean all && rm -rf /var/cache/yum &
fi

wait

echo
echo
echo '================================================================'
date
echo '----------------------------------------------------------------'
echo '                           Completed!                           '
$IS_CONTAINER && \
echo '                       -- In Container --                       '
echo '----------------------------------------------------------------'
echo -n '| Node     | '
uname -no
echo -n '| Kernel   | '
uname -sr
echo -n '| Platform | '
uname -m
echo    '| GPU      | '
which nvidia-smi 2>/dev/null >/dev/null && nvidia-smi -L | sed 's/^/|    ******| /'
echo '----------------------------------------------------------------'
df -h --sync --output=target,fstype,size,used,avail,pcent,source | sed 's/^/| /'
echo '================================================================'

# ----------------------------------------------------------------

trap - SIGTERM SIGINT EXIT

truncate -s 0 .bash_history
