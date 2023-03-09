# ================================================================
# Install CMake
# ================================================================

[ -e $STAGE/cmake ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    # Knwon issues:
    #   - CMake 3.22.0 + PyTorch 1.10.0 does not work.
    #     Still persist in 3.24.
    #     https://github.com/pytorch/pytorch/issues/69222
    #     https://github.com/pytorch/pytorch/issues/76105
    #     https://gitlab.kitware.com/cmake/cmake/-/issues/23805
    #   - CMake 3.21 has weird issue in find_library() breaking openmp build of LLVM 15.
    #     https://gitlab.kitware.com/cmake/cmake/-/issues/24221
    . "$ROOT_DIR/pkgs/utils/git/version.sh" Kitware/CMake,v
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO" cmake; do echo 'Retrying'; done
    cd cmake

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

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
sync "$STAGE" || true
