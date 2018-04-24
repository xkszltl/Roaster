# ================================================================
# Install CMake
# ================================================================

[ -e $STAGE/cmake ] && ( set -xe
    cd $SCRATCH
    
    # ------------------------------------------------------------

    until git clone --depth 1 --branch release $GIT_MIRROR/Kitware/CMake.git; do echo 'Retrying'; done
    cd CMake
    git checkout $(git tag | sed -n '/^[0-9\.]*$/p' | sort -V | tail -n1)

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
    rm -rf $SCRATCH/CMake
)
sudo rm -vf $STAGE/cmake
sync || true
