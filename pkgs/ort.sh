# ================================================================
# Compile ONNXRuntime
# ================================================================

[ -e $STAGE/ort ] && ( set -xe
    cd $SCRATCH

    # Known issues:
    # - Flake8 6.0.0 requires Python 3.8.1.
    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh"  \
        pypa/packaging,[3.6=21.]                    \
        cython/cython                               \
        benjaminp/six                               \
        'pycqa/flake8,[3.6=5.|3.7=5.]'              \
        'pytest-dev/pytest,[3.6=7.0.]'              \
        'numpy/numpy,v[3.6=v1.19.|3.7=v1.21.]'

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" Microsoft/onnxruntime,v
    until git clone -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd onnxruntime

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    git remote add patch "$GIT_MIRROR/xkszltl/onnxruntime.git"

    # Patches:
    # - ONNX/Ort has conflicting registration of proto when linked to shared protobuf.
    #   https://github.com/microsoft/onnxruntime/pull/12440
    # - Downloading archives from GitHub is unreliable.
    PATCHES="reg sysonnx abseil jemalloc"
    for i in $PATCHES; do
        git fetch patch "$i"
        git cherry-pick FETCH_HEAD
    done

    (
        set -xe

        cd cmake/external

        # rm -rf googletest protobuf
        # cp -rf /usr/local/src/{gtest,protobuf} ./
        # mv gtest googletest

        for i in ./*.cmake; do
            sed -i "s/$(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR_GITHUB")\(\/..*\/.*\.git\)/$(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR")\1/" "$i"
        done
        git --no-pager diff
    )

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        set +xe
        . "/opt/intel/$([ -e '/opt/intel/oneapi/mkl/latest/env/vars.sh' ] && echo 'oneapi/mkl/latest/env/vars.sh' || echo 'mkl/bin/mklvars.sh')" intel64
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        pushd $_

        (
            set -e
            # Known issues:
            # - ONNX 1.13.0 requires Protobuf 3.20.2 incompatible with Python 3.6.
            #   Build Ort in SCL Python as well to be compatible with ONNX.
            case "$DISTRO_ID-$DISTRO_VERSION_ID" in
            'centos-'* | 'fedora-'* | 'rhel-'* | 'scientific-'*)
                set +e
                . scl_source enable rh-python38 || exit 1
                set -e
                ;;
            esac

            # --------------------------------------------------------
            # Known issues:
            #   - Unresolved cublasLt symbols from libnvinfer_plugin.
            #     Probably due to incomplete dependency in CMake.
            #     Suppressed since it does not really hurt at runtime.
            #     https://github.com/microsoft/onnxruntime/issues/4625
            #   - Missing compute 3.5/3.7 support by default.
            #     https://github.com/microsoft/onnxruntime/issues/4935
            #   - Need ar/ranlib wrapper when using CUDA+LTO.
            #     https://github.com/microsoft/onnxruntime/issues/5031
            # --------------------------------------------------------
            # -DCMAKE_{C,CXX,CUDA}_COMPILER_{AR,RANLIB}="--plugin=$("$CC" --print-file-name=liblto_plugin.so)"
            "$TOOLCHAIN/cmake"                                      \
                -DCMAKE_AR="$(which "$AR")"                         \
                -DCMAKE_BUILD_TYPE=Release                          \
                -DCMAKE_C_COMPILER="$CC"                            \
                -DCMAKE_CUDA_ARCHITECTURES='35-virtual;60-real;61-real;70-real;75-real;80-real;80-virtual;86-real'              \
                -DCMAKE_{CUDA_HOST,CXX}_COMPILER="$CXX"             \
                -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache       \
                -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g $($TOOLCHAIN_CPU_NATIVE || echo '-march=haswell -mtune=generic')"  \
                -DCMAKE_{EXE,SHARED}_LINKER_FLAGS='-Xlinker --allow-shlib-undefined'                                            \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"               \
                -DCMAKE_POLICY_DEFAULT_CMP0060=NEW                  \
                -DCMAKE_RANLIB="$(which "$RANLIB")"                 \
                -DCMAKE_VERBOSE_MAKEFILE=ON                         \
                -DONNX_CUSTOM_PROTOC_EXECUTABLE="$(which protoc)"   \
                -DPython_ADDITIONAL_VERSIONS="$(python3 --version | sed -n 's/^Python[[:space:]]*\([0-9]*\.[0-9]*\)\..*/\1/p')" \
                -DPython_EXECUTABLE="$(which python3)"              \
                -DPython_FIND_UNVERSIONED_NAMES=FIRST               \
                -Deigen_SOURCE_PATH="/usr/local/include/eigen3"     \
                -Donnxruntime_BUILD_CSHARP=OFF                      \
                -Donnxruntime_BUILD_FOR_NATIVE_MACHINE="$($TOOLCHAIN_CPU_NATIVE && echo 'ON' || echo 'OFF')"                    \
                -Donnxruntime_BUILD_SHARED_LIB=ON                   \
                -Donnxruntime_CUDA_HOME="$(realpath -e "$(dirname "$(which nvcc)")/..")"                                        \
                -Donnxruntime_CUDNN_HOME='/usr'                     \
                -Donnxruntime_ENABLE_ATEN=ON                        \
                -Donnxruntime_ENABLE_EXTERNAL_CUSTOM_OP_SCHEMAS=OFF \
                -Donnxruntime_ENABLE_LANGUAGE_INTEROP_OPS=ON        \
                -Donnxruntime_ENABLE_LTO=ON                         \
                -Donnxruntime_ENABLE_PYTHON=ON                      \
                -Donnxruntime_PREFER_SYSTEM_LIB=ON                  \
                -Donnxruntime_RUN_ONNX_TESTS=ON                     \
                -Donnxruntime_TENSORRT_HOME='/usr'                  \
                -Donnxruntime_USE_AVX=ON                            \
                -Donnxruntime_USE_AVX2=ON                           \
                -Donnxruntime_USE_CUDA="$(which nvcc >/dev/null 2>&1 && echo 'ON' || echo 'OFF')"                               \
                -Donnxruntime_USE_DNNL=ON                           \
                -Donnxruntime_USE_EIGEN_FOR_BLAS=ON                 \
                -Donnxruntime_USE_FULL_PROTOBUF=ON                  \
                -Donnxruntime_USE_LLVM=ON                           \
                -Donnxruntime_USE_PREINSTALLED_EIGEN=OFF            \
                -Donnxruntime_USE_TENSORRT="$(false && which nvcc >/dev/null 2>&1 && echo 'ON' || echo 'OFF')"                  \
                -Donnxruntime_USE_TVM=OFF                           \
                -G"Ninja"                                           \
                ../cmake

            if ! time "$TOOLCHAIN/cmake" --build .; then
                printf '\033[33m[WARNING] Try to narrow down build issues on ONNXRuntime after build failure. You may Ctrl-C if it takes too long.\033[0m\n' >&2
                time "$TOOLCHAIN/cmake" --build . -- -k0 && time "$TOOLCHAIN/cmake" --build . -- -j1
                printf '\033[31m[ERROR] Failed to build ONNXRuntime.\033[0m\n' >&2
                exit 1
            fi
            time "$TOOLCHAIN/cmake" --build . --target install

            # Install unit tests.
            find . -maxdepth 1 -name 'onnxruntime_*test*' -type f -executable | xargs cp -dnrt "$INSTALL_ABS/bin/"

            # Install MKLML
            mkdir -p "$INSTALL_ABS/lib"
            ldd libonnxruntime.so | sed -n 's/.*libmklml_.* => *\(.*\) (0x[0-9a-f]*) *$/\1/p' | xargs -rn1 install -t "$INSTALL_ABS/lib"

            # Switch to disable testing because data downloading outside Azure is extremely slow.
            if true; then
                # Download from Azure Blob is not always correct.
                for retry in $(seq 3 -1 0); do
                    if [ "$retry" -le 0 ]; then
                        echo "Failed to download test data."
                        exit 1
                    fi
                    rm -rf 'models.zip'{,'.partial'}
                    if [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ]; then
                        curl -sSL 'https://repo.codingcafe.org/microsoft/onnxruntime/20190419.zip' > 'models.zip.partial' || continue
                    else
                        axel -n200 -o 'models.zip.partial' 'https://onnxruntimetestdata.blob.core.windows.net/models/20190419.zip' || continue
                    fi
                    md5sum -c <<< '3f46c31ee02345dbe707210b339e31fe models.zip.partial' || continue
                    mv -f 'models.zip'{'.partial',}
                    break
                done
                rm -rf models.zip.partial
                # Best effort since the zip is too large.
                if [ -e 'models.zip' ]; then
                    unzip -o models.zip -d ../models
                    rm -rf models.zip
                    time "$TOOLCHAIN/ctest" --output-on-failure || ! nvidia-smi
                fi
            fi

            python3 ../setup.py bdist_wheel
            pushd dist
            # ../../rename_manylinux.sh
            # "$ROOT_DIR/pkgs/utils/pip_install_from_wheel.sh" ./*-manylinux1_*.whl
            "$ROOT_DIR/pkgs/utils/pip_install_from_wheel.sh" ./onnxruntime-*-linux_*.whl
            popd
        )
        popd

        # Exclude MKL-DNN/ONNX files.
        pushd "$INSTALL_ROOT"
        for i in mkl-dnn onnx; do
            case "$DISTRO_ID" in
            'centos' | 'fedora' | 'rhel' | 'scientific')
                [ "$(rpm -qa "roaster-$i")" ] || continue
                rpm -ql "roaster-$i" | sed -n 's/^\//\.\//p' | xargs rm -rf
                ;;
            'debian' | 'linuxmint' | 'ubuntu')
                dpkg -l "roaster-$i" && dpkg -L "roaster-$i" | xargs -n1 | xargs -i -n1 find {} -maxdepth 0 -not -type d | sed -n 's/^\//\.\//p' | xargs rm -rf
                ;;
            esac
        done

        popd
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    (
        set -e
        case "$DISTRO_ID-$DISTRO_VERSION_ID" in
        'centos-'* | 'fedora-'* | 'rhel-'* | 'scientific-'*)
            set +e
            . scl_source enable rh-python38 || exit 1
            set -e
            ;;
        esac

        # Avoid having ort repo in sys.path.
        test_dir="$(mktemp -dp "$(pwd)" -t 'ort-test-XXXXXXXX.d')"
        pushd "$test_dir"

        # Test Python API and compatibility with ONNX.
        cat << ________EOF | sed 's/^            //' | python3 -
            import onnxruntime, onnxruntime.datasets, onnx, numpy

            sess = onnxruntime.InferenceSession(onnxruntime.datasets.get_example("sigmoid.onnx"), providers=['CPUExecutionProvider'])
            print(sess.run([sess.get_outputs()[0].name], {sess.get_inputs()[0].name: numpy.ones(sess.get_inputs()[0].shape).astype(numpy.float32)}))
________EOF

        popd
        rm -rf "$test_dir"
    )

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/onnxruntime
)
sudo rm -vf $STAGE/ort
sync || true
