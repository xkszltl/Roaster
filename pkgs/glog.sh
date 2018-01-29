# ================================================================
# Compile Glog
# ================================================================

[ -e $STAGE/glog ] && ( set -e
    cd $SCRATCH

    git clone $GIT_MIRROR/google/glog.git
    cd glog
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    # . scl_source enable devtoolset-7 || true

    # Downgrade to gcc-5 to solve "unrecognized relocation" error in caffe2.
    . scl_source enable devtoolset-4 || true

    mkdir -p build
    cd $_

    cmake                                               \
        -G"Ninja"                                       \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo               \
        -DCMAKE_C_COMPILER=gcc                          \
        -DCMAKE_CXX_COMPILER=g++                        \
        -DCMAKE_INSTALL_PREFIX=/usr/local               \
        ..

    time cmake --build .
    time cmake --build . --target test
    time cmake --build . --target install

    ldconfig &
    $IS_CONTAINER && ccache -C &
    cd
    rm -rf $SCRATCH/glog
    wait
)
rm -rvf $STAGE/glog
sync || true
