# ================================================================
# Compile LevelDB
# ================================================================

[ -e $STAGE/leveldb ] && ( set -e
    cd $SCRATCH

    git clone $GIT_MIRROR/google/leveldb.git
    cd leveldb
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    . scl_source enable devtoolset-7

    make -j$(nproc)
    make check -j$(nproc)
    mkdir -p /usr/local/include/leveldb/
    install include/leveldb/*.h $_
    mkdir -p /usr/local/lib
    install out-*/libleveldb.* $_

    ldconfig &
    ccache -C &
    cd
    rm -rf $SCRATCH/leveldb
    wait
) && rm -rvf $STAGE/leveldb
sync || true
