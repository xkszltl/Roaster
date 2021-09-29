# ================================================================
# Compile Zstd
# ================================================================

[ -e $STAGE/zstd ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" facebook/zstd,v
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd zstd

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        if false; then
            export CC="$(which ccache) $CC" CXX="$(which ccache) $CXX"
            export CFLAGS="$CFLAGS -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"
            export CXXFLAGS="$CXXFLAGS -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"

            # Known issues:
            #   - Retry due to potentially broken dependency graph.
            #     https://github.com/facebook/zstd/issues/2380
            #   - Parallel build does not work since v1.4.8.
            #     https://github.com/facebook/zstd/issues/2436
            for retry in $(seq 3 -1 0); do
                [ "$retry" -gt 0 ]
                make allmost manual && make -C contrib/pzstd all -j$(nproc) && make -C contrib/largeNbDicts all -j$(nproc) && break
            done
            # Only run quick tests (check) by default.
            # make test -j$(nproc)
            make check -j$(nproc)
            make PREFIX="$INSTALL_ABS" install -j
        else
            mkdir -p build-cmake
            cd "$_"

            "$TOOLCHAIN/cmake"                          \
                -DBUILD_TESTING=ON                      \
                -DCMAKE_BUILD_TYPE=Release              \
                -DCMAKE_C_COMPILER="$CC"                \
                -DCMAKE_CXX_COMPILER="$CXX"             \
                -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
                -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
                -DZSTD_BUILD_CONTRIB=ON                 \
                -DZSTD_BUILD_SHARED=ON                  \
                -DZSTD_BUILD_STATIC=ON                  \
                -DZSTD_MULTITHREAD_SUPPORT=ON           \
                -DZSTD_PROGRAMS_LINK_SHARED=ON          \
                -G"Ninja"                               \
                ../build/cmake

            time "$TOOLCHAIN/cmake" --build .
            time "$TOOLCHAIN/ctest" --label-exclude Medium --output-on-failure --verbose
            time "$TOOLCHAIN/cmake" --build . --target install
        fi
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/zstd
)
sudo rm -vf $STAGE/zstd
sync || true
