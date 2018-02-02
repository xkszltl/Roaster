# ================================================================
# Install Extra CUDA Packages
# ================================================================

[ -e $STAGE/cuda ] && ( set -e
    cd $SCRATCH

    export CUDNN_REPO=cudnn/v7.0.5

    if [ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ]; then
        curl -sSL https://repo.codingcafe.org/nvidia/$CUDNN_REPO/$(curl -sSL https://repo.codingcafe.org/nvidia/cudnn | sed -n 's/.*href="\(.*linux-x64.*\)".*/\1/p' | sort -V | tail -n1)
    else
        export HTTP_PROXY=proxy.codingcafe.org:8118
        [ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
        [ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
        [ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY

        curl -sSL https://developer.download.nvidia.com/compute/redist/$CUDNN_REPO/cudnn-9.1-linux-x64-v7.tgz
    fi | tar -zxvf - -C /usr/local/ --no-overwrite-dir

    wget https://repo.codingcafe.org/nvidia/nccl/$(curl -sSL https://repo.codingcafe.org/nvidia/nccl | sed -n 's/.*href="\(.*x86_64.*\)".*/\1/p' | sort -V | tail -n1)

    [ -e /usr/local/cuda/lib ] || ln -s /usr/local/cuda/lib{64,}
    tar -xvf nccl* -C /usr/local/cuda --strip-components=1 --no-overwrite-dir --skip-old-files
    [ -L /usr/local/cuda/lib ] && rm -f /usr/local/cuda/lib

    tar -Jtf nccl* | sed -n 's/^[^\/]*\/lib[^\/]*\(\/.*[^\/]\)$/ln -sf \/usr\/local\/cuda\/lib64\1 \/usr\/lib\1/p' | bash
    tar -Jtf nccl* | sed -n 's/^[^\/]*\(\/include\/.*[^\/]\)$/ln -sf \/usr\/local\/cuda\1 \/usr\1/p' | bash

    ldconfig

    cd $(dirname $(which nvcc))/../samples
    . scl_source enable devtoolset-6 || true
    export MPI_HOME=/usr/local/openmpi
    VERBOSE=1 time make -j$(nproc)
)
rm -rvf $STAGE/cuda
sync || true
