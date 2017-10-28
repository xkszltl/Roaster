# ================================================================
# Install CMake
# ================================================================

[ -e $STAGE/cmake ] && ( set -e
    cd $SCRATCH

    [ $GIT_MIRROR = $GIT_MIRROR_CODINGCAFE ] && export CMAKE_MIRROR=$GIT_MIRROR || export CMAKE_MIRROR=https://gitlab.kitware.com

    until git clone $CMAKE_MIRROR/cmake/cmake.git; do echo 'Retrying'; done
    cd cmake
    # git checkout $(git tag | sed -n '/^[0-9\.]*$/p' | sort -V | tail -n1)
    git checkout release

    . scl_source enable devtoolset-6

    ./bootstrap --prefix=/usr --parallel=$(nproc)
    VERBOSE=1 time make -j$(nproc)
    VERBOSE=1 time make -j install

    cd
    rm -rf $SCRATCH/cmake
) && rm -rvf $STAGE/cmake
sync || true
