# ================================================================
# Compile FFmpeg
# ================================================================

[ -e $STAGE/ffmpeg ] && ( set -xe
    cd $SCRATCH

    # Known issues:
    # - FFmpeg 6 is incompatible with torchvision as of Mar 2023.
    #   https://github.com/pytorch/vision/pull/7378
    [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ]                  \
    && . "$ROOT_DIR/pkgs/utils/git/version.sh" videolan/ffmpeg,n5.  \
    || GIT_MIRROR="https://git.videolan.org/git" . "$ROOT_DIR/pkgs/utils/git/version.sh" ffmpeg,n5.
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd ffmpeg

    # ------------------------------------------------------------

    # libwebp_error_to_averror() has been renamed with prefix ff_.
    # - https://github.com/FFmpeg/FFmpeg/commit/f99fed733d65d31d694641a3ce162b95eb348ac0
    # But an old piece was forgotten.
    # - https://github.com/FFmpeg/FFmpeg/blob/eacfcbae690f914a4b1b4ad06999f138540cc3d8/libavcodec/libwebpenc_common.c#L283
    # The problematic code is inside a macro and will not be used on new distros, but will fail on CentOS 7.
    sed -i 's/\([^[:alnum:]_]\)\(libwebp_error_to_averror(\)/\1ff_\2/' libavcodec/libwebpenc_common.c

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        export PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig:/usr/local/lib32/pkgconfig:$PKG_CONFIG_PATH:/usr/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/lib32/pkgconfig"
        export CC="ccache $CC" CXX="ccache $CXX"
        export C{,XX}FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"

        ./configure                 \
            --enable-cuda-nvcc      \
            --enable-gmp            \
            --enable-gpl            \
            --enable-gray           \
            --enable-libaom         \
            --enable-libbluray      \
            --enable-libcdio        \
            --enable-libcodec2      \
            --enable-libdav1d       \
            --enable-libdc1394      \
            --enable-libfontconfig  \
            --enable-libfreetype    \
            --enable-libjack        \
            $(true || echo --enable-libopencv)  \
            --enable-libpulse       \
            --enable-librabbitmq    \
            $(true || echo --enable-librav1e)   \
            --enable-libsmbclient   \
            --enable-libsnappy      \
            $(true || echo --enable-libvpx)     \
            --enable-libwebp        \
            --enable-libx264        \
            --enable-libx265        \
            --enable-libxml2        \
            $(true || echo --enable-libzimg)    \
            $(true || echo --enable-libzmq)     \
            $(true || echo --enable-lto)        \
            --enable-nonfree        \
            --enable-opengl         \
            --enable-openssl        \
            --enable-shared         \
            --enable-version3       \
            --logfile=/dev/null     \
            --nvcc="ccache $(which nvcc)"       \
            --prefix="$INSTALL_ABS" \

        time make -j"$(nproc)"
        LD_LIBRARY_PATH="$(set -e
                find -L . -name '*.so' -type f  \
                | xargs -rI{} dirname {}        \
                | xargs -rI{} realpath -e {}    \
                | sort -u                       \
                | paste -sd: -
            ):$LD_LIBRARY_PATH"                 \
        time make -j"$(nproc)" check
        time make -j           install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/ffmpeg
)
sudo rm -vf $STAGE/ffmpeg
sync "$STAGE" || true
