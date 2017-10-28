# ================================================================
# Compile Gflags
# ================================================================

[ -e $STAGE/gflags ] && ( set -e
    cd $SCRATCH

    git clone $GIT_MIRROR/gflags/gflags.git
    cd gflags
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    . scl_source enable devtoolset-7

    mkdir -p build
    cd $_

    cmake                                               \
        -G"Ninja"                                       \
        -DBUILD_PACKAGING=OFF                           \
        -DBUILD_SHARED_LIBS=ON                          \
        -DBUILD_TESTING=ON                              \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo               \
        -DCMAKE_INSTALL_PREFIX=/usr/local               \
        ..

    time cmake --build .
    time cmake --build . --target test
    time cmake --build . --target install

    ldconfig &
    ccache -C &
    cd
    rm -rf $SCRATCH/gflags
    wait
) && rm -rvf $STAGE/gflags
sync || true
