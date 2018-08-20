# ================================================================
# Install Extra CUDA Packages
# ================================================================

[ -e $STAGE/cuda ] && ( set -xe
    cd $SCRATCH

    [ -x '/usr/local/cuda/bin/nvcc' ]
    export CUDA_VER="$(/usr/local/cuda/bin/nvcc --version | sed -n 's/.*[[:space:]]V\([0-9\.]*\).*/\1/p')"
    export CUDA_VER_MAJOR="$(cut -d'.' -f1 <<< "$CUDA_VER")"
    export CUDA_VER_MINOR="$(cut -d'.' -f2 <<< "$CUDA_VER")"
    export CUDA_VER_BUILD="$(cut -d'.' -f3 <<< "$CUDA_VER")"

    export CUDNN_PREFIX="cudnn-$CUDA_VER_MAJOR.$CUDA_VER_MINOR-linux-x64-"
    export CUDNN_REPO=cudnn/v7.1.4

    if [ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ]; then
        CUDNN_DIR="https://repo.codingcafe.org/nvidia/$CUDNN_REPO"
        CUDNN_NAME="$(curl -sSL "$CUDNN_DIR" | sed -n 's/.*href="\('"$CUDNN_PREFIX"'.*\)".*/\1/p' | sort -V | tail -n1)"
    else
        CUDNN_DIR="https://developer.download.nvidia.com/compute/redist/$CUDNN_REPO"
        CUDNN_NAME="$CUDNN_PREFIX$(basename "$CUDNN_REPO" | cut -d. -f1,2 | sed 's/\.0$//').tgz"
    fi
    curl -sSL "$CUDNN_DIR/$CUDNN_NAME" | sudo tar -zxvf - -C "/usr/local/" --no-overwrite-dir

    NCCL_DIR="https://repo.codingcafe.org/nvidia/nccl"
    NCCL_NAME="$(curl -sSL "$NCCL_DIR" | sed -n 's/.*href="\(.*cuda'"$CUDA_VER_MAJOR.$CUDA_VER_MINOR"'_x86_64.*\)".*/\1/p' | sort -V | tail -n1)"
    wget -q "$NCCL_DIR/$NCCL_NAME"

    sudo [ -e /usr/local/cuda/lib ] || sudo ln -s /usr/local/cuda/lib{64,}
    sudo tar -xvf nccl* -C /usr/local/cuda --strip-components=1 --no-overwrite-dir --skip-old-files
    sudo [ -L /usr/local/cuda/lib ] && sudo rm -f /usr/local/cuda/lib

    tar -Jtf nccl* | sed -n 's/^[^\/]*\/lib[^\/]*\(\/.*[^\/]\)$/sudo ln -sf \/usr\/local\/cuda\/lib64\1 \/usr\/lib\1/p' | bash
    tar -Jtf nccl* | sed -n 's/^[^\/]*\(\/include\/.*[^\/]\)$/sudo ln -sf \/usr\/local\/cuda\1 \/usr\1/p' | bash

    sudo ldconfig

    cd $(dirname $(which nvcc))/../samples
    . scl_source enable devtoolset-7 || true
    export MPI_HOME=/usr/local/openmpi
    sudo make -j clean
    VERBOSE=1 time sudo make -j$(nproc)
)
sudo rm -vf $STAGE/cuda
sync || true
