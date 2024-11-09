# ================================================================
# Compile Axel
# ================================================================

[ -e $STAGE/axel ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    # Known issues:
    # - Axel 2.17.14 requires autoconf 2.72 not yet available in Debian 12 as of Nov 2024.
    #   https://github.com/axel-download-accelerator/axel/issues/435
    #   https://github.com/axel-download-accelerator/axel/commit/1179ed90553a1a448a7d30d282895faf236abd7d
    . "$ROOT_DIR/pkgs/utils/git/version.sh" axel-download-accelerator/axel,v2.17.13
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
