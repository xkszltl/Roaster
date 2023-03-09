# ================================================================
# Compile XGBoost
# ================================================================

[ -e $STAGE/xgboost ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" dmlc/xgboost,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd xgboost

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        mkdir -p build
        cd $_

        "$TOOLCHAIN/cmake"                          \
            -DBUILD_WITH_CUDA_CUB=ON                \
            -DBUILD_STATIC_LIB=OFF                  \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DFORCE_COLORED_OUTPUT=ON               \
            -DGOOGLE_TEST=ON                        \
            -DGPU_COMPUTE_VER='61;70;75;80;89'      \
            -DUSE_CXX14_IF_AVAILABLE=ON             \
            -DUSE_OPENMP=ON                         \
            -DUSE_CUDA=ON                           \
            -DUSE_NCCL=ON                           \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -G"Ninja"                               \
            ..

        time "$TOOLCHAIN/cmake" --build .
        # Parallel testing does not work as of v1.7.4.
        time "$TOOLCHAIN/ctest" --output-on-failure
        time "$TOOLCHAIN/cmake" --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/xgboost
)
sudo rm -vf $STAGE/xgboost
sync "$STAGE" || true
