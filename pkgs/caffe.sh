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
        . scl_source enable devtoolset-6

        cmake                                   \
            -G"Unix Makefiles"                  \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo   \
            -DCMAKE_VERBOSE_MAKEFILE=ON         \
            -DBLAS=Open                         \
            -DUSE_NCCL=ON                       \
            ..

        time cmake --build . -- -j $(nproc)
        time cmake --build . --target test -- -j $(nproc)
        time cmake --build . --target install -- -j $(nproc)
    )

    ldconfig &
    ccache -C &
    cd
    rm -rf $SCRATCH/caffe
    wait
) && rm -rvf $STAGE/caffe
sync || true
