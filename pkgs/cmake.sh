# ================================================================
# Install CMake
# ================================================================

[ -e $STAGE/cmake ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" Kitware/CMake,v
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO" cmake; do echo 'Retrying'; done
    cd cmake

    # Known issues:
    #   - Patch CMake 3.18.3 issue with FindPython.
    #     https://gitlab.kitware.com/cmake/cmake/-/issues/21223
    git remote add kitware https://gitlab.kitware.com/cmake/cmake.git
    git fetch kitware
    git cherry-pick 6c094c1

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-9
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
