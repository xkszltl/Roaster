# ================================================================
# Compile RocksDB
# ================================================================

[ -e $STAGE/rocksdb ] && ( set -xe
    cd $SCRATCH

    pip install -U git+$GIT_MIRROR/Maratyszcza/{confu,PeachPy}.git

    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/facebook/rocksdb.git; do echo 'Retrying'; done
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
        set -xe

        export C{,XX}FLAGS="-g"
        export DEBUG_LEVEL=0
        # export DISABLE_WARNING_AS_ERROR=ON

        # On CentOS 7, "/usr/local/bin" is hardcoded in ssh/bash, but not sudo.
        # Patch $PATH for fpm from rubygem.
        which fpm || export PATH="/usr/local/bin:$PATH"

        time make -j$(nproc) {static,shared}_lib
        time make -j$(nproc) package
        # time make -j$(nproc) check
        # time make -j install{,-shared}
    )

    yum install -y package/rocksdb-*.rpm || yum update -y package/rocksdb-*.rpm

    $IS_CONTAINER && ccache -C &
    cd
    rm -rf $SCRATCH/rocksdb
    wait
)
rm -rvf $STAGE/rocksdb
sync || true
