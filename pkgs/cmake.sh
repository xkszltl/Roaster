# ================================================================
# Install CMake
# ================================================================

[ -e $STAGE/cmake ] && ( set -xe
    cd $SCRATCH
    
    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" Kitware/CMake,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO" cmake; do echo 'Retrying'; done
    cd cmake

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        set -xe

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
