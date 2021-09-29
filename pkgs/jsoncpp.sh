# ================================================================
# Compile JsonCpp
# ================================================================

[ -e $STAGE/jsoncpp ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    # Use master until patch released: https://github.com/open-source-parsers/jsoncpp/commit/a4fb5db54389e618a4968a3feb7f20d5ce853232
    . "$ROOT_DIR/pkgs/utils/git/version.sh" open-source-parsers/jsoncpp,master
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd jsoncpp

    git remote add patch "$GIT_MIRROR/xkszltl/jsoncpp.git"
    git fetch patch

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        mkdir -p build
        cd $_

        "$TOOLCHAIN/cmake"                          \
            -DBUILD_SHARED_LIBS=ON                  \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DJSONCPP_WITH_CMAKE_PACKAGE=ON         \
            -G"Ninja"                               \
            ..

        time "$TOOLCHAIN/cmake" --build .
        # Parallel test does not work.
        time "$TOOLCHAIN/ctest" --output-on-failure
        time "$TOOLCHAIN/cmake" --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/jsoncpp
)
sudo rm -vf $STAGE/jsoncpp
sync || true
