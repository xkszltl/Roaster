# ================================================================
# Install CMake
# ================================================================

[ -e $STAGE/cmake ] && ( set -xe
    cd $SCRATCH
    
    # ------------------------------------------------------------

    until git clone --depth 1 --single-branch -b "$(git ls-remote --tags "$GIT_MIRROR/Kitware/CMake.git" | sed -n 's/.*[[:space:]]refs\/tags\/\(v[0-9\.]*\)$/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/Kitware/CMake.git" "cmake"; do echo 'Retrying'; done
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
