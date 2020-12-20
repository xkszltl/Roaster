# ================================================================
# Compile Zstd
# ================================================================

[ -e $STAGE/zstd ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" facebook/zstd,v
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd zstd

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-9 || exit 1
            set -xe
            export CC="gcc" CXX="g++"
            ;;
        'ubuntu')
            export CC="gcc-8" CXX="g++-8"
            ;;
        esac

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        export CC="$(which ccache) $CC" CXX="$(which ccache) $CXX"
        export CFLAGS="$CFLAGS -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"
        export CXXFLAGS="$CXXFLAGS -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"

        # Known issues:
        #   - Retry due to potentially broken dependency graph.
        #     https://github.com/facebook/zstd/issues/2380
        for retry in $(seq 3 -1 0); do
            [ "$retry" -gt 0 ]
            make all -j$(nproc) && break
        done
        # Only run quick tests (check) by default.
        # make test -j$(nproc)
        make check -j$(nproc)
        make PREFIX="$INSTALL_ABS" install -j
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/zstd
)
sudo rm -vf $STAGE/zstd
sync || true
