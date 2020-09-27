# ================================================================
# Compile Eigen
# ================================================================

[ -e $STAGE/eigen ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" eigenteam/eigen-git-mirror,
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO" eigen; do echo 'Retrying'; done
    cd eigen

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

        cmake                                       \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DEIGEN_TEST_CUDA=ON                    \
            -DEIGEN_TEST_CXX11=ON                   \
            -DOpenGL_GL_PREFERENCE=GLVND            \
            -G"Ninja"                               \
            ..

        time cmake --build . --target blas
        # Check may take hours.
        # time cmake --build . --target check
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/eigen
)
sudo rm -vf $STAGE/eigen
sync || true
