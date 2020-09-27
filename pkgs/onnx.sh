# ================================================================
# Compile ONNX
# ================================================================

[ -e $STAGE/onnx ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" python/typing cython/cython benjaminp/six numpy/numpy,v

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" onnx/onnx,master
    until git clone -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done

    cd onnx

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # pushd third_party/pybind11
    # git checkout master
    # rm -rf pybind11
    # cp -rf /usr/local/src/pybind11 pybind11
    # popd

    # git commit -am "Update submodule \"pybind11\"."

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

        # --------------------------------------------------------
        # Hack for protoc-gen-mypy bug:
        #     https://github.com/onnx/onnx/issues/1952
        # --------------------------------------------------------

        if which python3; then
            PY_DIR="$(readlink -f "$INSTALL_ROOT/../python")"
            mkdir -p "$PY_DIR"
            ln -sf "$(which python3)" "$PY_DIR/python"
            export PATH="$PY_DIR:$PATH"
        fi

        CMAKE_ARGS="$CMAKE_ARGS
            -DBUILD_SHARED_LIBS=ON
            -DCMAKE_BUILD_TYPE=Release
            -DCMAKE_C_COMPILER='$(which "$CC")'
            -DCMAKE_C_COMPILER_LAUNCHER=ccache
            -DCMAKE_CXX_COMPILER='$(which "$CXX")'
            -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
            -DONNX_GEN_PB_TYPE_STUBS=ON
        " ONNX_ML=1 "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" .

        mkdir -p build
        cd $_

        cmake                                       \
            -DBENCHMARK_ENABLE_LTO=ON               \
            -DBUILD_ONNX_PYTHON=ON                  \
            -DBUILD_SHARED_LIBS=ON                  \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DONNX_BUILD_BENCHMARKS=ON              \
            -DONNX_BUILD_TESTS=OFF                  \
            -DONNX_GEN_PB_TYPE_STUBS=ON             \
            -DONNX_ML=ON                            \
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
