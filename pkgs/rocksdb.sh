# ================================================================
# Compile RocksDB
# ================================================================

[ -e $STAGE/rocksdb ] && ( set -e
    cd $SCRATCH

    pip install -U git+$GIT_MIRROR/Maratyszcza/{confu,PeachPy}.git

    until git clone --depth 1 --no-single-branch $GIT_MIRROR/facebook/rocksdb.git; do echo 'Retrying'; done
    cd rocksdb
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    . scl_source enable devtoolset-7 || true

#     mkdir -p build
#     cd $_
#     cmake                                   \
#         -G"Ninja"                           \
#         -DCMAKE_BUILD_TYPE=Release          \
#         -DCMAKE_C{,XX}_FLAGS="-g"           \
#         -DCMAKE_VERBOSE_MAKEFILE=ON         \
#         -DWITH_BZ2=ON                       \
#         -DWITH_JEMALLOC=ON                  \
#         -DWITH_LIBRADOS=ON                  \
#         -DWITH_LZ4=ON                       \
#         -DWITH_SNAPPY=ON                    \
#         -DWITH_ZLIB=ON                      \
#         -DWITH_ZSTD=ON                      \
#         ..
#
#     time cmake --build . --target install

    (
        set -e

        export DISABLE_WARNING_AS_ERROR=ON
        export C{,XX}FLAGS="-g"

        time make -j$(nproc) static_lib
        time make -j$(nproc) shared_lib
        # time make -j$(nproc) check
        # time make -j install
        # time make -j install-shared
        time make -j package
    )

    yum install -y package/rocksdb-*.rpm || yum update -y package/rocksdb-*.rpm

    $IS_CONTAINER && ccache -C &
    cd
    rm -rf $SCRATCH/rocksdb
    wait
)
rm -rvf $STAGE/rocksdb
sync || true
