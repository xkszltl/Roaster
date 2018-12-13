# ================================================================
# Compile ONNX
# ================================================================

[ -e $STAGE/onnx ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" cython/cython numpy/numpy,v protocolbuffers/protobuf,v benjaminp/six
    "$ROOT_DIR/pkgs/utils/pip_install_from_wheel.sh" future

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" onnx/onnx,master
    until git clone -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done

    cd onnx

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    pushd third_party/pybind11
    git checkout master
    # rm -rf pybind11
    # cp -rf /usr/local/src/pybind11 pybind11
    popd

    git commit -am "Update submodule \"pybind11\"."

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        CMAKE_ARGS="
            -DBUILD_SHARED_LIBS=ON
            -DCMAKE_BUILD_TYPE=Release
            -DCMAKE_C_COMPILER=gcc
            -DCMAKE_CXX_COMPILER=g++
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache
            -DONNX_GEN_PB_TYPE_STUBS=ON
        " "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" .

        mkdir -p build
        cd $_

        cmake                                       \
            -DBENCHMARK_ENABLE_LTO=ON               \
            -DBUILD_ONNX_PYTHON=ON                  \
            -DBUILD_SHARED_LIBS=ON                  \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER=gcc                  \
            -DCMAKE_CXX_COMPILER=g++                \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DONNX_BUILD_BENCHMARKS=ON              \
            -DONNX_BUILD_TESTS=OFF                  \
            -DONNX_GEN_PB_TYPE_STUBS=ON             \
            -DPYBIND11_PYTHON_VERSION=2.7           \
            -G"Ninja"                               \
            ..

        time cmake --build .
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/onnx
)
sudo rm -vf $STAGE/onnx
sync || true
