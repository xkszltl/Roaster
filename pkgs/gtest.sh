# ================================================================
# Compile GTest/GMock
# ================================================================

[ -e $STAGE/gtest ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" google/googletest,release-
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO" gtest; do echo 'Retrying'; done
    cd gtest

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-9
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

        cmake                                       \
            -DBUILD_SHARED_LIBS=ON                  \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -Dgmock_build_tests=OFF                 \
            -Dgtest_build_samples=ON                \
            -Dgtest_build_tests=ON                  \
            -G"Ninja"                               \
            ..

        time cmake --build .
        time cmake --build . --target test || true
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/gtest
)
sudo rm -vf $STAGE/gtest
sync || true
