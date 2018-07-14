# ================================================================
# Compile Jemalloc
# ================================================================

[ -e $STAGE/jemalloc ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    until git clone --depth 1 --single-branch -b "$(git ls-remote --tags "$GIT_MIRROR/jemalloc/jemalloc.git" | sed -n 's/.*[[:space:]]refs\/tags\/\([0-9\.]*\)[[:space:]]*$/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/jemalloc/jemalloc.git"; do echo 'Retrying'; done
    cd jemalloc

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        set -xe

        ./autogen.sh                    \
            --enable-{prof,xmalloc}     \
            --prefix="$INSTALL_ABS"     \
            --with-jemalloc-prefix=""

        time make -j$(nproc) dist
        time make -j$(nproc)
        time make -j$(nproc) install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/jemalloc
)
sudo rm -vf $STAGE/jemalloc
sync || true
