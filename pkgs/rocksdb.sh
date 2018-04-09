# ================================================================
# Compile RocksDB
# ================================================================

[ -e $STAGE/rocksdb ] && ( set -xe
    cd $SCRATCH

    sudo pip install -U git+$GIT_MIRROR/Maratyszcza/{confu,PeachPy}.git

    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/facebook/rocksdb.git; do echo 'Retrying'; done
    cd rocksdb
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +x
        . scl_source enable devtoolset-7 || true
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_
        cmake                                       \
            -G"Ninja"                               \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$TOOLCHAIN/cc"      \
            -DCMAKE_C{,XX}_FLAGS="-g"               \
            -DCMAKE_CXX_COMPILER="$TOOLCHAIN/c++"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DCMAKE_VERBOSE_MAKEFILE=ON             \
            -DWITH_BZ2=ON                           \
            -DWITH_JEMALLOC=ON                      \
            -DWITH_LIBRADOS=ON                      \
            -DWITH_LZ4=ON                           \
            -DWITH_SNAPPY=ON                        \
            -DWITH_ZLIB=ON                          \
            -DWITH_ZSTD=ON                          \
            ..
        time cmake --build . --target install

        # time make -j$(nproc) {static,shared}_lib
        # time make -j$(nproc) package
        # time make -j$(nproc) check
        # time make -j install{,-shared}
    )

    # sudo yum install -y package/rocksdb-*.rpm || sudo yum update -y package/rocksdb-*.rpm

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/rocksdb
)
sudo rm -vf $STAGE/rocksdb
sync || true
