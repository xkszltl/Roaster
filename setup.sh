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

. <(sed 's/^\(..*\)/export DISTRO_\1/' '/etc/os-release')

case "$DISTRO_ID" in
"centos" | "fedora" | "rhel")
    export RPM_CACHE_REPO="/etc/yum.repos.d/codingcafe-cache.repo"
    ;;
esac

# ----------------------------------------------------------------

[ "$IS_CONTAINER" ] || export IS_CONTAINER=$([ ! -e /proc/1/cgroup ] || [ "$(sed -n 's/^[^:]*:[^:]*:\(..\)/\1/p' /proc/1/cgroup | wc -l)" -le 0 ] || echo true)
[ "$IS_CONTAINER" ] || export IS_CONTAINER=$([ ! -e /.dockerenv ] || echo true)
[ "$IS_CONTAINER" ] || export IS_CONTAINER=$([ ! -e /run/.containerenv ] || echo true)
[ "$IS_CONTAINER" ] || export IS_CONTAINER=false

if ! "$IS_CONTAINER" && [ "$(whoami)" = 'root' ]; then
    echo "Please use a non-root user with sudo permission."
    exit 1
fi

# ----------------------------------------------------------------

export ROOT_DIR="$(realpath -e "$(dirname "$0")")"

export STAGE='/etc/roaster/stage'

# ----------------------------------------------------------------

export SCRATCH='/tmp/scratch'
for candidate in '/media/Scratch'; do
    if ! $IS_CONTAINER && [ -d "$candidate" ]; then
        export SCRATCH="$(mktemp -p "$candidate")"
        break
    fi
done

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

if ! which sudo; then
    if [ "_$(whoami)" != '_root' ]; then
        echo 'Insufficient permission to bootstrap. Please install sudo manually or provide root access.'
        exit 1
    fi

    case "$DISTRO_ID" in
    "centos" | "fedora" | "rhel")
        which dnf >/dev/null 2>&1 && dnf makecache -y || yum makecache -y
        which dnf >/dev/null 2>&1 && dnf install -y sudo || yum install -y sudo
        ;;
    "debian" | "linuxmint" | "ubuntu")
        apt-get update -y
        DEBIAN_FRONTEND=noninteractive apt-get install -y sudo
        ;;
    esac
fi

if ! which ps || ! which xargs; then
    case "$DISTRO_ID" in
    "centos" | "fedora" | "rhel")
        sudo which dnf >/dev/null 2>&1 && dnf makecache -y || yum makecache -y
        sudo which dnf >/dev/null 2>&1 && sudo dnf install -y findutils procps-ng || sudo yum install -y findutils procps-ng
        ;;
    "debian" | "linuxmint" | "ubuntu")
        sudo apt-get update -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y findutils procps
        ;;
    esac
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

rm -rvf "$SCRATCH"
mkdir -p "$SCRATCH"
# $IS_CONTAINER || mount -t tmpfs -o size=100% tmpfs $SCRATCH
pushd "$SCRATCH"

# ================================================================
# Initialize Setup Stage
# ================================================================

[ -d "$STAGE" ] && [ $# -eq 0 ] || ( set -xe
    sudo rm -rvf "$STAGE"
    sudo mkdir -p "$(dirname "$STAGE")/.$(basename "$STAGE")"
    cd $_
    [ $# -gt 0 ] && sudo touch $@ || sudo touch repo font pkg-stable pkg-skip pkg-all fpm auth vim tmux tex ss intel lm-sensors lz4 zstd cmake hiredis ccache c-ares axel ipt cuda gdrcopy ucx ompi llvm-{gcc,clang} boost jemalloc eigen openblas gtest benchmark gflags glog snappy protobuf nsync grpc catch2 jsoncpp rapidjson simdjson utf8proc pugixml pybind libpng mkl-dnn ispc halide opencv leveldb rocksdb lmdb onnx pytorch torchvision apex ort
    sync || true
    cd "$SCRATCH"
    sudo mv -vf "$(dirname "$STAGE")/.$(basename "$STAGE")" $STAGE
)

# Refer to "man ccache" for supported units.
if which ccache 2>/dev/null >/dev/null; then
    ! $IS_CONTAINER || ccache -M 128Gi
    ccache -z
fi

for i in $(echo "
    env/mirror
    env/cred
    repo
    env/pkg
    font
    pkg
    fpm
    firewall
    auth
    vim
    tmux
    slurm
    nagios
    shadowsocks
    texlive
    intel
    lm-sensors
    lz4
    zstd
    cmake
    hiredis
    ccache
    c-ares
    axel
    ipt
    cuda
    gdrcopy
    ucx
    openmpi
    nccl
    argyll
    llvm
    boost
    jemalloc
    eigen
    openblas
    gtest
    benchmark
    gflags
    glog
    snappy
    protobuf
    nsync
    catch2
    jsoncpp
    rapidjson
    simdjson
    utf8proc
    pugixml
    pybind
    grpc
    libpng
    libgdiplus
    mkl-dnn
    ispc
    halide
    opencv
    leveldb
    rocksdb
    lmdb
    onnx
    caffe
    pytorch
    torchvision
    apex
    ort
"); do
    . "$ROOT_DIR/pkgs/$i.sh"
done

# ================================================================
# Cleanup
# ================================================================

popd
rm -rvf "$SCRATCH"
sudo ldconfig

which ccache 2>/dev/null >/dev/null && ccache -s

if $IS_CONTAINER; then
    case "$DISTRO_ID" in
    "centos" | "fedora" | "rhel")
        sudo which dnf >/dev/null 2>&1 && sudo dnf autoremove -y || sudo yum autoremove -y
        ! sudo which dnf >/dev/null 2>&1 || sudo dnf clean all --enablerepo='*'
        sudo yum clean all
        sudo rm -rf /var/cache/yum
        # DNF may log GB of data here.
        sudo rm -rf /var/log/dnf.librepo.log
        ;;
    "debian" | "linuxmint" | "ubuntu")
        sudo apt-get autoremove -y
        sudo apt-get clean
        sudo rm -rf /var/lib/apt/lists/*
        ;;
    esac
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
    # $IS_CONTAINER && ccache -Cz >/dev/null 2>/dev/null
    echo '----------------------------------------------------------------'
fi
df -h --sync --output=target,fstype,size,used,avail,pcent,source | sed 's/^/| /'
echo '================================================================'

# ----------------------------------------------------------------

trap - SIGTERM SIGINT EXIT

truncate -s 0 .bash_history
