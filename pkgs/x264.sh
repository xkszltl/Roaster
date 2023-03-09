# ================================================================
# Compile x264 codec
# ================================================================

[ -e $STAGE/x264 ] && ( set -xe
    cd $SCRATCH

    [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ]                  \
    && . "$ROOT_DIR/pkgs/utils/git/version.sh" videolan/x264,stable \
    || GIT_MIRROR="https://code.videolan.org" . "$ROOT_DIR/pkgs/utils/git/version.sh" videolan/x264,stable
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd x264

    # ------------------------------------------------------------

    ./version.sh                                                                                    \
    | sed -n 's/^[[:space:]]*#define[[:space:]][[:space:]]*X264_POINTVER[[:space:]][[:space:]]*//p' \
    | tr -d '"'                                                                                     \
    | tr '[:space:]' '\t'                                                                           \
    | cut -f1                                                                                       \
    | grep .                                                                                        \
    | head -n1                                                                                      \
    | xargs -I{} git tag {}

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set -e

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        export CC="ccache $CC" CXX="ccache $CXX"
        export C{,XX}FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"

        ./configure                 \
            --enable-lto            \
            --enable-shared         \
            --enable-static         \
            --prefix="$INSTALL_ABS" \

        time make -j"$(nproc)"
        time make -j           install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/x264
)
sudo rm -vf $STAGE/x264
sync "$STAGE" || true
