# ================================================================
# Compile RocksDB
# ================================================================

[ -e $STAGE/rocksdb ] && ( set -xe
    cd $SCRATCH

    sudo pip install -U git+$GIT_MIRROR/Maratyszcza/{confu,PeachPy}.git

    # ------------------------------------------------------------

    until git clone --depth 1 --single-branch -b "$(git ls-remote --tags "$GIT_MIRROR/facebook/rocksdb.git" | sed -n 's/.*[[:space:]]refs\/tags\/\(v[0-9\.]*\)[[:space:]]*$/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/facebook/rocksdb.git"; do echo 'Retrying'; done
    # until git clone --depth 1 --single-branch -b master "$GIT_MIRROR/facebook/rocksdb.git"; do echo 'Retrying'; done
    cd rocksdb
    # git remote add patch "https://github.com/xkszltl/rocksdb.git"
    # git pull --no-edit patch gtest

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        . /opt/intel/tbb/bin/tbbvars.sh intel64
        set -xe

        if false; then
            mkdir -p build
            cd $_
            # The NDEBUG in non-debug cmake build leads to test-related compile error.
            cmake                                       \
                -DCMAKE_BUILD_TYPE=RelWithDebInfo       \
                -DCMAKE_C{,XX}_FLAGS="-O3 -g"           \
                -DCMAKE_C{,XX}_FLAGS_RELWITHDEBINFO=""  \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
                -DCMAKE_VERBOSE_MAKEFILE=ON             \
                -FAIL_ON_WARNINGS=OFF                   \
                -DUSE_RTTI=1                            \
                -DWITH_BZ2=ON                           \
                -DWITH_JEMALLOC=OFF                     \
                -DWITH_LIBRADOS=ON                      \
                -DWITH_LZ4=ON                           \
                -DWITH_SNAPPY=ON                        \
                -DWITH_TBB=ON                           \
                -DWITH_ZLIB=ON                          \
                -DWITH_ZSTD=ON                          \
                -G"Ninja"                               \
                ..
            time cmake --build .
            time cmake --build . --target check
            time cmake --build . --target install
        else
            . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
            export CC="$TOOLCHAIN/cc"
            export CXX="$TOOLCHAIN/c++"
            export LD="$TOOLCHAIN/ld"
            time make DEBUG_LEVEL=0 -j$(nproc) {static,shared}_lib
            # time make -j$(nproc) package
            # time make -j$(nproc) check
            time make DEBUG_LEVEL=0 INSTALL_PATH="$INSTALL_ABS" -j install{,-shared}
        fi
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/rocksdb
)
sudo rm -vf $STAGE/rocksdb
sync || true
