# ================================================================
# Compile CCache
# ================================================================

[ -e $STAGE/ccache ] && ( set -xe
    cd $SCRATCH
    
    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" ccache/ccache,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd ccache

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-8
            set -xe
            ;;
        'ubuntu')
            export CC="$(which gcc-8)" CXX="$(which g++-8)"
            ;;
        esac

        time ./autogen.sh
        time ./configure --prefix="$INSTALL_ABS"
        time make -j$(nproc)
        time make install -j
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/ccache
)
sudo rm -vf $STAGE/ccache
sync || true
