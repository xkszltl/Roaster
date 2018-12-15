# ================================================================
# Compile ONNXRuntime
# ================================================================

[ -e $STAGE/onnxruntime ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" Microsoft/onnxruntime,master
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd onnxruntime

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7 rh-python36
        . "/opt/intel/mkl/bin/mklvars.sh" intel64
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        cmake                                               \
            -DBUILD_SHARED_LIBS=ON                          \
            -DCMAKE_BUILD_TYPE=Release                      \
            -DCMAKE_C_COMPILER=gcc                          \
            -DCMAKE_CXX_COMPILER=g++                        \
            -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache   \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
            -DCMAKE_POLICY_DEFAULT_CMP0003=NEW              \
            -DCMAKE_POLICY_DEFAULT_CMP0060=NEW              \
            -DCMAKE_VERBOSE_MAKEFILE=ON                     \
            -DONNX_CUSTOM_PROTOC_EXECUTABLE="/usr/local/bin/protoc" \
            -Deigen_SOURCE_PATH="/usr/local/include/eigen3" \
            -Donnxruntime_BUILD_SHARED_LIB=ON               \
            -Donnxruntime_ENABLE_PYTHON=ON                  \
            -Donnxruntime_RUN_ONNX_TESTS=ON                 \
            -Donnxruntime_USE_CUDA=ON                       \
            -Donnxruntime_USE_JEMALLOC=OFF                  \
            -Donnxruntime_USE_LLVM=ON                       \
            -Donnxruntime_USE_MKLDNN=OFF                    \
            -Donnxruntime_USE_MKLML=OFF                     \
            -Donnxruntime_USE_OPENMP=ON                     \
            -Donnxruntime_USE_PREBUILT_PB=ON                \
            -Donnxruntime_USE_PREINSTALLED_EIGEN=ON         \
            -Donnxruntime_USE_TVM=OFF                       \
            -G"Ninja"                                       \
            ../cmake

        time cmake --build . --target
        time cmake --build . --target install
        time cmake --build . --target test || ! nvidia-smi

        # Exclude MKL-DNN/ONNX files.
        pushd "$INSTALL_ROOT"
        rpm -ql codingcafe-mkl-dnn | sed -n 's/^\//\.\//p' | xargs rm -rf
        rpm -ql codingcafe-onnx | sed -n 's/^\//\.\//p' | xargs rm -rf
        popd
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"
    
    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/onnxruntime
)
sudo rm -vf $STAGE/onnxruntime
sync || true
