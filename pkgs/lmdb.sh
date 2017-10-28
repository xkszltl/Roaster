# ================================================================
# Compile LMDB
# ================================================================

[ -e $STAGE/lmdb ] && ( set -e
    cd $SCRATCH

    git clone $GIT_MIRROR/LMDB/lmdb.git
    cd lmdb/libraries/liblmdb
    git checkout $(git tag | sed -n '/^LMDB_[0-9\.]*$/p' | sort -V | tail -n1)

    . scl_source enable devtoolset-7

    make -j$(nproc)
    make test
    make install -j

    ldconfig &
    ccache -C &
    cd
    rm -rf $SCRATCH/lmdb
    wait
) && rm -rvf $STAGE/lmdb
sync || true
