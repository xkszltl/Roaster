# ================================================================
# Compile Gflags
# ================================================================

[ -e $STAGE/hiredis ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" redis/hiredis,v
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd hiredis

    PATCHES=''
    git remote add patch "$GIT_MIRROR/xkszltl/hiredis.git"
    for i in $PATCHES; do
        git fetch patch
        git cherry-pick "patch/$i"
    done

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        mkdir -p build
        cd $_

        # Known issues:
        # - ENABLE_SSL_TESTS may have a trailing comma in name.
        "$TOOLCHAIN/cmake"                          \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DENABLE_EXAMPLES=ON                    \
            -DENABLE_SSL=ON                         \
            -DENABLE_SSL_TESTS{,','}=ON             \
            -G"Ninja"                               \
            ..

        time "$TOOLCHAIN/cmake" --build .
        # Need a server to run client tests.
        ! which redis-server >/dev/null 2>&1 || time "$TOOLCHAIN/ctest" --output-on-failure -j"$(nproc)"
        time "$TOOLCHAIN/cmake" --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/hiredis
)
sudo rm -vf $STAGE/hiredis
sync || true
