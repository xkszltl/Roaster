# ================================================================
# Compile LMDB
# ================================================================

[ -e $STAGE/lmdb ] && ( set -xe
    cd $SCRATCH

    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/LMDB/lmdb.git; do echo 'Retrying'; done
    cd lmdb
    git checkout $(git tag | sed -n '/^LMDB_[0-9\.]*$/p' | sort -V | tail -n1)

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +x
        . scl_source enable devtoolset-7 || true
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        cd libraries/liblmdb

        make -j$(nproc)
        make test
        make PREFIX="$INSTALL_ABS" install -j
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/lmdb
)
rm -rvf $STAGE/lmdb
sync || true
