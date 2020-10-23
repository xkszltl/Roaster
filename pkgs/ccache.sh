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
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-9 || exit 1
            set -xe
            export CC="gcc" CXX="g++"
            ;;
        'ubuntu')
            export CC="gcc-8" CXX="g++-8"
            ;;
        esac

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
                -DZSTD_FROM_INTERNET=OFF                \
                -G"Ninja"                               \
                ..
            time cmake --build .
            CTEST_PARALLEL_LEVEL="$(nproc)" time cmake --build . --target test
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
