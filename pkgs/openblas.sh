# ================================================================
# Compile OpenBLAS
# ================================================================

[ -e $STAGE/openblas ] && ( set -e
    cd $SCRATCH

    git clone $GIT_MIRROR/xianyi/OpenBLAS.git
    cd OpenBLAS
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    . scl_source enable devtoolset-7

    # mkdir -p build
    # cd $_

    # cmake                                   \
    #     -G"Ninja"                           \
    #     -DCMAKE_BUILD_TYPE=Release          \
    #     -DCMAKE_C_COMPILER=gcc              \
    #     -DCMAKE_CXX_COMPILER=g++            \
    #     -DCMAKE_INSTALL_PREFIX=/usr/local   \
    #     -DCMAKE_VERBOSE_MAKEFILE=ON         \
    #     ..

    # time cmake --build .
    # time cmake --build . --target test
    # time cmake --build . --target install

    make PREFIX=/usr/local
    make PREFIX=/usr/local install

    ldconfig &
    $IS_CONTAINER && ccache -C &
    cd
    rm -rf $SCRATCH/OpenBLAS
    wait
)
rm -rvf $STAGE/openblas
sync || true
