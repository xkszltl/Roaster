# ================================================================
# Compile Gflags
# ================================================================

[ -e $STAGE/gflags ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" gflags/gflags,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd gflags

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

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        "$TOOLCHAIN/cmake"                          \
            -DBUILD_PACKAGING=OFF                   \
            -DBUILD_SHARED_LIBS=ON                  \
            -DBUILD_TESTING=ON                      \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -G"Ninja"                               \
            ..

        time "$TOOLCHAIN/cmake" --build .
        time "$TOOLCHAIN/ctest" --output-on-failure -j"$(nproc)"
        time "$TOOLCHAIN/cmake" --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/gflags
)
sudo rm -vf $STAGE/gflags
sync || true
