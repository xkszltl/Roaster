# ================================================================
# Compile PyBind11
# ================================================================

[ -e $STAGE/pybind ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" python-attrs/attrs cython/cython numpy/numpy,v pytest-dev/pluggy pytest-dev/pytest

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" pybind/pybind11,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done

    cd pybind11

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7 rh-python36
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        PYBIND11_USE_CMAKE=ON "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" .

        mkdir -p build
        cd $_

        cmake                                       \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER=gcc                  \
            -DCMAKE_CXX_COMPILER=g++                \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -G"Ninja"                               \
            ..

        time cmake --build .
        time cmake --build . --target pytest
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/pybind11
)
sudo rm -vf $STAGE/pybind
sync || true
