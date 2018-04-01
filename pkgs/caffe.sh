# ================================================================
# Compile Caffe
# ================================================================

[ -e $STAGE/caffe ] && ( set -xe
    cd $SCRATCH

    until git clone --depth 1 $GIT_MIRROR/BVLC/caffe.git; do echo 'Retrying'; done
    cd caffe

    # ------------------------------------------------------------

    mkdir -p build
    cd $_
    ( set -xe
        . scl_source enable devtoolset-6 || true

        # CUDA 9.x has removed Fermi (2.x) support.
        # Use CUDA_ARCH_NAME to fix compile error "Unsupported gpu architecture 'compute_20'".
        cmake                                   \
            -G"Ninja"                           \
            -DCMAKE_BUILD_TYPE=Release          \
            -DCMAKE_C{,XX}_FLAGS="-g"           \
            -DCMAKE_INSTALL_PREFIX="/usr"       \
            -DCMAKE_VERBOSE_MAKEFILE=ON         \
            -DCUDA_ARCH_NAME=Pascal             \
            -DBLAS=MKL                          \
            -DUSE_NCCL=ON                       \
            ..

        time cmake --build .
        nvidia-smi && time cmake --build . --target runtest
        time cmake --build . --target install
    )

    ldconfig &
    $IS_CONTAINER && ccache -C &
    cd
    rm -rf $SCRATCH/caffe
    wait
)
sudo rm -vf $STAGE/caffe
sync || true
