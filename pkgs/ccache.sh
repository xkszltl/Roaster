# ================================================================
# Compile CCache
# ================================================================

[ -e $STAGE/ccache ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" ccache/ccache,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd ccache

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        export PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig:/usr/local/lib32/pkgconfig:$PKG_CONFIG_PATH"

        # CCache 4.0 has switched to CMake.
        if false; then
            time ./autogen.sh
            time ./configure --prefix="$INSTALL_ABS"
            time make -j$(nproc)
            time make install -j
        else
            mkdir -p build
            cd $_

            cmake                                       \
                -DCMAKE_BUILD_TYPE=Release              \
                -DCMAKE_C_COMPILER="$CC"                \
                -DCMAKE_CXX_COMPILER="$CXX"             \
                -DCMAKE_C{,XX}_COMPILER_LAUNCHER="$(which ccache 2>/dev/null)"                  \
                -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
                -DENABLE_IPO=ON                         \
                -DENABLE_TESTING=ON                     \
                -DHIREDIS_FROM_INTERNET=OFF             \
                -DREDIS_STORAGE_BACKEND=OFF             \
                -DZSTD_FROM_INTERNET=OFF                \
                -G"Ninja"                               \
                ..
            time cmake --build .
            time ctest --output-on-failure -j"$(nproc)"
            time cmake --build . --target install
        fi
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/ccache
)
sudo rm -vf $STAGE/ccache
sync || true
