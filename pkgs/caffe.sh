# ================================================================
# Compile Caffe
# ================================================================

[ -e $STAGE/caffe ] && ( set -e
    cd $SCRATCH

    until git clone $GIT_MIRROR/BVLC/caffe.git; do echo 'Retrying'; done
    cd caffe

    # ------------------------------------------------------------

    mkdir -p build
    cd $_
    ( set -e
        . scl_source enable devtoolset-6 || true

        # CUDA 9.x has removed Fermi (2.x) support.
        # Use CUDA_ARCH_NAME to fix compile error "Unsupported gpu architecture 'compute_20'".
        cmake                                   \
            -G"Unix Makefiles"                  \
            -DCMAKE_BUILD_TYPE=Release          \
            -DCMAKE_C_FLAGS="-g"                \
            -DCMAKE_CXX_FLAGS="-g"              \
            -DCMAKE_VERBOSE_MAKEFILE=ON         \
            -DCUDA_ARCH_NAME=Pascal             \
            -DBLAS=Open                         \
            -DUSE_NCCL=ON                       \
            ..

        time cmake --build . -- -j $(nproc)
        time cmake --build . --target test -- -j $(nproc)
        time cmake --build . --target install -- -j $(nproc)
    )

    ldconfig &
    $IS_CONTAINER && ccache -C &
    cd
    rm -rf $SCRATCH/caffe
    wait
)
rm -rvf $STAGE/caffe
sync || true
