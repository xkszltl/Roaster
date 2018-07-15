# ================================================================
# Compile LMDB
# ================================================================

[ -e $STAGE/lmdb ] && ( set -xe
    cd $SCRATCH

    until git clone --depth 1 --single-branch -b "$(git ls-remote --tags "$GIT_MIRROR/LMDB/lmdb.git" | sed -n 's/.*[[:space:]]refs\/tags\/\(LMDB_[0-9\.]*\)[[:space:]]*$/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/LMDB/lmdb.git"; do echo 'Retrying'; done
    cd lmdb

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        cd libraries/liblmdb

        cat Makefile                                                                                \
        | sed "s/^\(CC[[:space:]]*=[[:space:]]*\).*/\1$(sed 's/\//\\\//g' <<< "$TOOLCHAIN/cc")/"    \
        | sed "s/^\(prefix[[:space:]]*=[[:space:]]*\).*/\1$(sed 's/\//\\\//g' <<< "$INSTALL_ABS")/" \
        > .Makefile
        mv -f {.,}Makefile

        make -j$(nproc)
        make test
        make "$INSTALL_ABS" install -j
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/lmdb
)
sudo rm -vf $STAGE/lmdb
sync || true
