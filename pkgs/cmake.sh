# ================================================================
# Install CMake
# ================================================================

[ -e $STAGE/cmake ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    # Pin to v3.18.5 due to https://gitlab.kitware.com/cmake/cmake/-/issues/21469
    . "$ROOT_DIR/pkgs/utils/git/version.sh" Kitware/CMake,v3.18
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO" cmake; do echo 'Retrying'; done
    cd cmake

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

        ./bootstrap --prefix="$INSTALL_ABS" --parallel=$(nproc)
        VERBOSE=1 time make -j$(nproc)
        VERBOSE=1 time make -j install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/cmake
)
sudo rm -vf $STAGE/cmake
sync || true
