# ================================================================
# Build nvcodec headers
# ================================================================

[ -e $STAGE/nvcodec ] && ( set -xe
    cd $SCRATCH

    [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ]                          \
    && . "$ROOT_DIR/pkgs/utils/git/version.sh" videolan/nv-codec-headers,n  \
    || GIT_MIRROR="https://git.videolan.org/git/ffmpeg" . "$ROOT_DIR/pkgs/utils/git/version.sh" nv-codec-headers,n
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO" nvcodec; do echo 'Retrying'; done
    cd nvcodec

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    make -j"$(nproc)"
    make -j install DESTDIR="$INSTALL_ROOT"

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/nvcodec
)
sudo rm -vf $STAGE/nvcodec
sync || true
