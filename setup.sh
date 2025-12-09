#!/bin/bash

set -e

if [ "$PPID" -le 1 ]; then
    printf '\033[36m[INFO] Started from process %d. Re-entry for protection.\033[0m\n' "$PPID" >&2
    $0 $@
    exit $!
fi

trap "trap - TERM && kill -- -$$" EXIT INT TERM

# ================================================================
# Environment Configuration
# ================================================================

export ROOT_DIR="$(realpath -e "$(dirname "$0")")"
export STAGE='/etc/roaster/stage'

. <(sed 's/^\(..*\)/export DISTRO_\1/' '/etc/os-release')

case "$DISTRO_ID" in
'centos' | 'fedora' | 'rhel' | 'scientific')
    export RPM_CACHE_REPO="/etc/yum.repos.d/codingcafe-mirror.repo"
    ;;
esac

# ----------------------------------------------------------------

export IS_CONTAINER="$("$ROOT_DIR/inside_container.sh" && echo 'true' || echo 'false')"
[ "$IS_CONTAINER" ]

if ! "$IS_CONTAINER" && [ "$(whoami)" = 'root' ]; then
    printf '\033[31m[ERROR] Please use a non-root user with sudo permission.\033[0m\n' >&2
    exit 1
fi

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
        printf '\033[31m[ERROR] Insufficient permission to bootstrap. Please install sudo manually or provide root access.\033[0m\n' >&2
        exit 1
    fi

    case "$DISTRO_ID" in
    'centos' | 'fedora' | 'rhel')
        which dnf >/dev/null 2>&1 && dnf makecache -y || yum makecache -y
        which dnf >/dev/null 2>&1 && dnf install -y sudo || yum install -y sudo
        ;;
    'debian' | 'linuxmint' | 'ubuntu' | 'scientific')
        apt-get update -o 'DPkg::Lock::Timeout=3600' -y
        DEBIAN_FRONTEND=noninteractive apt-get install -o 'DPkg::Lock::Timeout=3600' -y sudo
        ;;
    esac
fi

if ! which ps || ! which xargs; then
    case "$DISTRO_ID" in
    'centos' | 'fedora' | 'rhel' | 'scientific')
        sudo which dnf >/dev/null 2>&1 && dnf makecache -y || yum makecache -y
        sudo which dnf >/dev/null 2>&1 && sudo dnf install -y findutils procps-ng || sudo yum install -y findutils procps-ng
        ;;
    'debian' | 'linuxmint' | 'ubuntu')
        sudo apt-get update -o 'DPkg::Lock::Timeout=3600' -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -o 'DPkg::Lock::Timeout=3600' -y findutils procps
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
    [ $# -gt 0 ] && sudo touch $@ || sudo touch repo font pkg-stable pkg-skip pkg-all fpm auth vim tmux tex ss trojan intel nasm lm-sensors lz4 zstd cmake hiredis ccache c-ares axel ipt python-3.{7,8,9,10,11,12,13,14} cuda gdrcopy ucx ompi llvm-{gcc,clang} boost jemalloc eigen openblas gtest benchmark gflags glog snappy jsoncpp rapidjson simdjson utf8proc pugixml protobuf nsync grpc catch2 pybind libpng x264 x265 mkl-dnn ispc halide xgboost sentencepiece opencv leveldb rocksdb lmdb nvcodec ffmpeg onnx pytorch torchvision apex ort
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
    trojan
    texlive
    intel
    nasm
    lm-sensors
    lz4
    zstd
    cmake
    hiredis
    ccache
    c-ares
    axel
    ipt
    python
    cuda
    nvcodec
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
    jsoncpp
    rapidjson
    simdjson
    utf8proc
    pugixml
    protobuf
    nsync
    catch2
    pybind
    grpc
    libpng
    libgdiplus
    x264
    x265
    mkl-dnn
    ispc
    halide
    xgboost
    sentencepiece
    opencv
    leveldb
    rocksdb
    lmdb
    nvcodec
    ffmpeg
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
    'centos' | 'fedora' | 'rhel' | 'scientific')
        sudo which dnf >/dev/null 2>&1 && sudo dnf autoremove -y || sudo yum autoremove -y
        ! sudo which dnf >/dev/null 2>&1 || sudo dnf clean all --enablerepo='*'
        sudo yum clean all
        sudo rm -rf /var/cache/yum
        # DNF may log GB of data here.
        sudo rm -rf /var/log/dnf.librepo.log
        ;;
    'debian' | 'linuxmint' | 'ubuntu')
        sudo apt-get autoremove -o 'DPkg::Lock::Timeout=3600' -y
        sudo apt-get clean -o 'DPkg::Lock::Timeout=3600'
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

trap - EXIT INT TERM
