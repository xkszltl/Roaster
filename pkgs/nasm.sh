# ================================================================
# Compile NASM
# ================================================================

[ -e $STAGE/nasm ] && ( set -xe
    cd $SCRATCH

    # Known issues:
    # - NASM 2.16 requires autoconf 2.71 in build.
    #   https://github.com/netwide-assembler/nasm/commit/b6151260a1d09a2e98f4d9074080e89fb6b3aa98
    . "$ROOT_DIR/pkgs/utils/git/version.sh" netwide-assembler/nasm,nasm-2.15.
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd nasm

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set -e

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        export CFLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"
        export CC_AR="$AR" CC_RANLIB="$RANLIB"

        ./autogen.sh
        ./configure                 \
            --enable-ccache         \
            --enable-lto            \
            --prefix="$INSTALL_ABS" \

        time make -j"$(nproc)" all manpages
        time make -j"$(nproc)" test
        time make -j           install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/nasm
)
sudo rm -vf $STAGE/nasm
sync "$STAGE" || true
