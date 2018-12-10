#!/bin/bash

set -e

if [ $PPID -le 1 ]; then
    echo "Started from process $PPID. Re-entry for protection."
    $0 $@
    exit $!
fi

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# ================================================================
# Environment Configuration
# ================================================================

export IS_CONTAINER=$([ -e /proc/1/cgroup ] && [ $(sed -n 's/^[^:]*:[^:]*:\(..\)/\1/p' /proc/1/cgroup | wc -l) -gt 0 ] && echo true || echo false)

if ! "$IS_CONTAINER" && [ "$(whoami)" = 'root' ]; then
    echo "Please use a non-root user with sudo permission."
    exit 1
fi

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
which nvidia-smi >/dev/null 2>/dev/null && nvidia-smi -L | sed 's/^/|    ******| /'
echo    '| Sensor   | '
which sensors >/dev/null 2>/dev/null && sensors | sed 's/^/|    ******| /'
echo -n '| User     | '
whoami
echo -n '|          | '
id
echo '----------------------------------------------------------------'
df -h --sync --output=target,fstype,size,used,avail,pcent,source | sed 's/^/| /'
echo '================================================================'
echo
echo

# ================================================================
# Cache sudo Credentials
# ================================================================

if ! rpm -q sudo > /dev/null; then
    if [ "$(whoami)" == 'root' ]; then
        yum install -y sudo
    else
        echo 'Insufficient permission to bootstrap. Please install sudo manually or provide root access.'
    fi
fi

. "$ROOT_DIR/pkgs/utils/sudo_ping_daemon.sh"

sudo -llp "
----------------------------------------------------------------
 We would like to pre-activate a sudo session.
 Please provide your password.
 Session may still timeout, depending on system configuration.
 You will be asked for password again at that time.
----------------------------------------------------------------
[sudo] password for %p: "

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

[ -d $STAGE ] && [ $# -eq 0 ] || ( set -xe
    sudo rm -rvf $STAGE
    sudo mkdir -p $(dirname $STAGE)/.$(basename $STAGE)
    cd $_
    [ $# -gt 0 ] && sudo touch $@ || sudo touch repo font pkg-{skip,all} fpm auth slurm nagios ss tex ccache cmake axel intel ipt ompi cuda llvm-{gcc,clang} boost jemalloc eigen openblas gtest gflags glog snappy protobuf catch2 pybind mkl-dnn halide opencv leveldb rocksdb lmdb onnx caffe caffe2
    sync || true
    cd $SCRATCH
    sudo mv -vf $(dirname $STAGE)/.$(basename $STAGE) $STAGE
)

which ccache 2>/dev/null >/dev/null && ccache -z

for i in $(echo "
    env-mirror
    repo
    env-pkg
    font
    pkg
    fpm
    auth
    slurm
    nagios
    shadowsocks
    texlive
    ccache
    cmake
    axel
    intel
    ipt
    openmpi
    cuda
    llvm
    boost
    jemalloc
    eigen
    openblas
    gtest
    gflags
    glog
    snappy
    protobuf
    catch2
    pybind
    mkl-dnn
    halide
    opencv
    leveldb
    rocksdb
    lmdb
    onnx
    caffe
    caffe2
"); do
    . $ROOT_DIR/pkgs/$i.sh
done

# ================================================================
# Cleanup
# ================================================================

cd

rm -rvf $SCRATCH
sudo ldconfig

which ccache 2>/dev/null >/dev/null && ccache -s

if $IS_CONTAINER; then
    sudo yum autoremove -y
    sudo yum clean all
    sudo rm -rf /var/cache/yum
fi

# ----------------------------------------------------------------

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
which nvidia-smi >/dev/null 2>/dev/null && nvidia-smi -L | sed 's/^/|    ******| /'
echo    '| Sensor   | '
which sensors >/dev/null 2>/dev/null && sensors | sed 's/^/|    ******| /'
echo -n '| User     | '
whoami
echo -n '|          | '
id
echo '----------------------------------------------------------------'
if which ccache >/dev/null 2>/dev/null; then
    ccache -s | sed 's/^/| /'
    $IS_CONTAINER && ccache -Cz >/dev/null 2>/dev/null
    echo '----------------------------------------------------------------'
fi
df -h --sync --output=target,fstype,size,used,avail,pcent,source | sed 's/^/| /'
echo '================================================================'

# ----------------------------------------------------------------

trap - SIGTERM SIGINT EXIT

truncate -s 0 .bash_history
