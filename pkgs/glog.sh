# ================================================================
# Compile Glog
# ================================================================

[ -e $STAGE/glog ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" google/glog,v0.4.
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd glog

    # ------------------------------------------------------------

    # Known issues:
    #   - Expose IsGoogleLoggingInitialized() API in v0.5.0.
    #     https://github.com/google/glog/pull/651
    #   - Disable patch for v0.4.
    # PATCHES='81e0d61'
    # git fetch origin master
    # for i in $PATCHES; do
    #     git cherry-pick "$i"
    # done

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
            -G"Ninja"                               \
            ..

        time "$TOOLCHAIN/cmake" --build .
        # One test randomly failed on Ubuntu recently (Sep 28, 2019).
        time "$TOOLCHAIN/ctest" --output-on-failure -j"$(nproc)" || true
        time "$TOOLCHAIN/cmake" --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/glog
)
sudo rm -vf $STAGE/glog
sync || true
