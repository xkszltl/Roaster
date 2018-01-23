# ================================================================
# Install CMake
# ================================================================

[ -e $STAGE/cmake ] && ( set -e
    cd $SCRATCH

    until git clone $GIT_MIRROR/Kitware/CMake.git; do echo 'Retrying'; done
    cd CMake
    # git checkout $(git tag | sed -n '/^[0-9\.]*$/p' | sort -V | tail -n1)
    git checkout release

    . scl_source enable devtoolset-7 || true

    ./bootstrap --prefix=/usr --parallel=$(nproc)
    VERBOSE=1 time make -j$(nproc)
    VERBOSE=1 time make -j install

    cd
    rm -rf $SCRATCH/CMake
)
rm -rvf $STAGE/cmake
sync || true
