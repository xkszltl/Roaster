# ================================================================
# Compile PyBind11
# ================================================================

[ -e $STAGE/pybind ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" python-attrs/attrs cython/cython pytest-dev/pluggy pytest-dev/pytest numpy/numpy,v

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" pybind/pybind11,v
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd pybind11

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    git remote add patch 'https://github.com/xkszltl/pybind11.git'
    PATCHES=""
    for i in $PATCHES; do
        git fetch patch "$i"
        git cherry-pick 'FETCH_HEAD'
    done

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

        PYBIND11_USE_CMAKE=ON "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" .

        mkdir -p build
        cd $_

        "$TOOLCHAIN/cmake"                          \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -G"Ninja"                               \
            ..

        time "$TOOLCHAIN/cmake" --build .

        # --------------------------------------------------
        # PyTest crashed recently (Jan 2019):
        #     INTERNALERROR > pluggy.manager.PluginValidationError: unknown hook 'pytest_namespace' in plugin
        # Bypass test temporarily and wait for a fix.
        # --------------------------------------------------
        time "$TOOLCHAIN/cmake" --build . --target pytest || true

        time "$TOOLCHAIN/cmake" --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/pybind11
)
sudo rm -vf $STAGE/pybind
sync || true
