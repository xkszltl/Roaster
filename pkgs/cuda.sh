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

    cd /usr/local/cuda/samples
    . scl_source enable devtoolset-6 || true
    export MPI_HOME=/usr/local/openmpi
    sudo make -j clean
    VERBOSE=1 time sudo make -j$(nproc)
)
sudo rm -vf $STAGE/cuda
sync || true
