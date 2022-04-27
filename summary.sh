#!/bin/bash

set +x
set -e

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

cd "$(dirname "$0")"

for cmd in bc docker find git grep jq sed xargs; do
    if ! which "$cmd" >/dev/null; then
        printf '\033[31m[ERROR] Command "%s" not found.\033[0m\n' "$cmd" >&2
        exit 1
    fi
done

[ "$DOCKER_IMAGE" ] || DOCKER_IMAGE='roasterproject/centos'

if ! [ "$SUMMARIZING_IN_CONTAINER" ]; then
    printf '## New features\n\n'
    printf '%s ...\n\n' '-'

    printf '## Docker collection\n\n'
    for dist in CentOS Debian Ubuntu; do
        img="$(sed 's/\/\/*/\//' <<< "/$DOCKER_IMAGE" | sed 's/\/*$//' | sed 's/\/[^\/]*$//' | sed 's/^\///')/$(tr 'A-Z' 'a-z' <<< "$dist")"
        ! grep "^$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$img"):" <<< "$DOCKER_IMAGE:" >/dev/null || img="$DOCKER_IMAGE"
        printf '%s %s\n' '-' "$img"
    done
    printf '\n'

    printf '### Size\n\n'
    for dist in CentOS Debian Ubuntu; do
        img="$(sed 's/\/\/*/\//' <<< "/$DOCKER_IMAGE" | sed 's/\/*$//' | sed 's/\/[^\/]*$//' | sed 's/^\///')/$(tr 'A-Z' 'a-z' <<< "$dist")"
        ! grep "^$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$img"):" <<< "$dist:" || img="$dist"
        sudo docker images -q "$img" | grep '[^[:space:]]' >/dev/null || continue
        printf '%s %s: %s GiB, %s %% space efficiency\n'                    \
            '-'                                                             \
            "$dist"                                                         \
            "$(sudo docker inspect "$img"                                   \
                | jq -er '.[0].Size'                                        \
                | grep -v 'null'                                            \
                | xargs -r printf '(%s+2^29)/2^30\n'                        \
                | bc                                                        \
                | sed 's/^[[:space:]]*$/N\/A/'                              \
            )"                                                              \
            "$(DOCKER_IMAGE="$img" ./docker_efficiency.sh 2>&1 >/dev/null   \
                | grep '\[INFO\]'                                           \
                | sed -n 's/.* Space efficiency \([0-9\.]*\) *%.*/\1/p'     \
            )"
    done
    printf '\n'

    sudo docker run --entrypoint '' --rm -e SUMMARIZING_IN_CONTAINER=true -it -v "$(pwd):$(pwd):ro" "$DOCKER_IMAGE" "$(pwd)/$(basename "$0")"
else
    [ ! -e '/etc/os-release' ] || . <(sed 's/^\(..*\)/export DISTRO_\1/' '/etc/os-release')

    printf '## Roaster info\n\n'
    (
        set -e
        cd '/etc/roaster/scripts'
        git describe --tags | xargs printf '%s Version: %s\n\n' '-'
        if ! git diff --exit-code --name-only >/dev/null; then
            printf '### Build-time changes\n\n'
            printf '```\n'
            git diff
            printf '```\n\n'
        fi
    )

    printf '## Highlights\n\n'
    case "$DISTRO_ID" in
    "centos" | "fedora" | "rhel" | "scientific")
        printf '%s GCC\n' '-'
        printf '    - %s: ' "$DISTRO_ID"
        ! which scl >/dev/null 2>&1                             \
        || scl -l                                               \
        | grep '^devtoolset\-[1-9][0-9]*'                       \
        | sort -rV                                              \
        | xargs -I{} scl enable {} 'gcc --version | head -n1'   \
        | cut -d' ' -f3                                         \
        | paste -sd/                                            \
        | xargs -r printf '%s (SCL devtoolset) and '
        gcc --version | head -n1 | cut -d' ' -f3 | xargs printf '%s\n'
        printf '%s Python\n' '-'
        printf '    - %s: ' "$DISTRO_ID"
        ! which scl >/dev/null 2>&1                     \
        || scl -l                                       \
        | grep '^rh-python[1-9][0-9]*'                  \
        | sort -rV                                      \
        | xargs -I{} scl enable {} 'python3 --version'  \
        | cut -d' ' -f2                                 \
        | paste -sd/                                    \
        | xargs -r printf '%s (SCL rh-python) and '
        python3 --version | cut -d' ' -f2 | xargs printf '%s\n'
        for tuple in                            \
            'LLVM,roaster-llvm,'                \
            'CMake,roaster-cmake,'              \
            'CCache,roaster-ccache,'            \
            'CUDA,cuda-libraries-devel-*,'      \
            'cuDNN,libcudnn*-devel,    '        \
            'TensorRT,libnvinfer-devel,    '    \
            'NCCL,libnccl-devel,    '           \
            'OpenMPI,roaster-ompi,'             \
            'UCX,roaster-ucx,    '              \
            'Intel MPI,intel-oneapi-mpi-devel,' \
            'MKL,intel-oneapi-mkl-devel'        \
            'Eigen,roaster-eigen,'              \
            'OpenBLAS,roaster-openblas,'        \
            'Boost,roaster-boost,'              \
            'Protobuf,roaster-protobuf,'        \
            'Pybind,roaster-pybind11,'          \
            'gRPC,roaster-grpc,'                \
            'RocksDB,roaster-rocksdb,'          \
            'TexLive,roaster-texlive,'          \
            'Qt,qt5-qtbase-devel,'              \
            'OpenCV,roaster-opencv,'
        do
            cut -d, -f2 <<< "$tuple,"                                   \
            | xargs rpm -qa                                             \
            | sed -n 's/.*\-\([0-9][[:alnum:]\.]*\)\-[0-9][^\-]*$/\1/p' \
            | sort -rV                                                  \
            | head -n1                                                  \
            | xargs printf '%s- %s %s\n' "$(cut -d, -f3 <<< "$tuple,,")" "$(cut -d, -f1 <<< "$tuple")"
        done
        ;;
    "debian" | "linuxmint" | "ubuntu")
        printf '%s GCC\n' '-'
        find '/usr/bin' -maxdepth 1 -name 'gcc-*' -not -type d  \
        | xargs -n1 basename                                    \
        | grep -e '^gcc$' -e '^gcc-[1-9][0-9]*$'                \
        | sed 's/$/ \-\-version | head \-n1/'                   \
        | sh                                                    \
        | cut -d' ' -f4                                         \
        | sort -rV                                              \
        | paste -sd/                                            \
        | xargs printf '    - %s: %s\n' "$DISTRO_ID"
        printf '%s Python\n' '-'
        python3 --version | cut -d' ' -f2 | xargs printf '    - %s: %s\n' "$DISTRO_ID"
        for tuple in                            \
            'LLVM,roaster-llvm,'                \
            'CMake,roaster-cmake,'              \
            'CCache,roaster-ccache,'            \
            'CUDA,cuda-libraries-dev-*,'        \
            'cuDNN,libcudnn*-dev,    '          \
            'TensorRT,libnvinfer-dev,    '      \
            'NCCL,libnccl-dev,    '             \
            'OpenMPI,roaster-ompi,'             \
            'UCX,roaster-ucx,    '              \
            'Intel MPI,intel-oneapi-mpi-devel,' \
            'MKL,intel-oneapi-mkl-devel'        \
            'Eigen,roaster-eigen,'              \
            'OpenBLAS,roaster-openblas,'        \
            'Boost,roaster-boost,'              \
            'Protobuf,roaster-protobuf,'        \
            'Pybind,roaster-pybind11,'          \
            'gRPC,roaster-grpc,'                \
            'RocksDB,roaster-rocksdb,'          \
            'TexLive,roaster-texlive,'          \
            'Qt,qtbase5-dev,'                   \
            'OpenCV,roaster-opencv,'
        do
            cut -d, -f2 <<< "$tuple,"               \
            | xargs dpkg -l                         \
            | grep '^ii[[:space:]]'                 \
            | sed 's/[[:space:]][[:space:]]*/ /g'   \
            | cut -d' ' -f3                         \
            | cut -d- -f1                           \
            | sort -rV                              \
            | head -n1                              \
            | xargs printf '%s- %s %s\n' "$(cut -d, -f3 <<< "$tuple,,")" "$(cut -d, -f1 <<< "$tuple")"
        done
        ;;
    esac
    for tuple in                    \
        'ONNX,onnx,'                \
        'PyTorch,torch,'            \
        'ONNXRuntime,onnxruntime,'
    do
        cat <(if which scl >/dev/null 2>&1; then scl enable rh-python38 'python3 -m pip list --format=json'; fi)    \
            <(python3 -m pip list --format=json)                                                                    \
        | jq -er '.[] | select(."name" == "'"$(cut -d, -f2 <<< "$tuple,")"'").version'                              \
        | head -n1                                                                                                  \
        | xargs printf '%s- %s %s\n' "$(cut -d, -f3 <<< "$tuple,,")" "$(cut -d, -f1 <<< "$tuple")"
    done
    printf '\n'

    printf '## Roaster packages\n\n'
    printf '```\n'
    case "$DISTRO_ID" in
    "centos" | "fedora" | "rhel" | "scientific")
        rpm -qa 'roaster-*' | sort
        ;;
    "debian" | "linuxmint" | "ubuntu")
        dpkg -l 'roaster-*' | grep '^ii' | sed 's/  */ /g' | cut -d' ' -f2,3
        ;;
    esac
    printf '```\n\n'

    printf '### Nvidia packages\n\n'
    printf '```\n'
    case "$DISTRO_ID" in
    "centos" | "fedora" | "rhel" | "scientific")
        rpm -qa 'cuda*' | sort
        rpm -qa 'libcudnn*' | sort
        rpm -qa 'libnvinfer*' | sort
        rpm -qa 'libnccl*' | sort
        ;;
    "debian" | "linuxmint" | "ubuntu")
        dpkg -l {cuda,lib{cudnn,nvinfer,nccl}}'*' | grep '^ii' | sed 's/  */ /g' | cut -d' ' -f2,3
        ;;
    esac
    printf '```\n\n'
fi

trap - SIGTERM SIGINT EXIT
