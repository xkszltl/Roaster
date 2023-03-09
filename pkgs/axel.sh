# ================================================================
# Compile Axel
# ================================================================

[ -e $STAGE/axel ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" axel-download-accelerator/axel,v
    until git clone -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd axel

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        time autoreconf -fiv
        time ./configure --disable-Werror --prefix="$INSTALL_ABS"
        time make -j$(nproc)
        time make install -j
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/axel
)
sudo rm -vf $STAGE/axel
sync "$STAGE" || true
