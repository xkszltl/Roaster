# ================================================================
# Compile ONNXRuntime
# ================================================================

[ -e $STAGE/ort ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh"  \
        pypa/packaging                              \
        cython/cython                               \
        benjaminp/six                               \
        pycqa/flake8                                \
        'pytest-dev/pytest,[3.6=7.0.]'              \
        'numpy/numpy,v[3.6=v1.19.|3.7=v1.21.]'

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" Microsoft/onnxruntime,v
    until git clone -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd onnxruntime

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    git remote add patch "$GIT_MIRROR/xkszltl/onnxruntime.git"

    # Patches:
    # - Ort 1.12.0 is incompatible with json-devel 3.6.1 on CentOS 7.
    #   https://github.com/microsoft/onnxruntime/issues/12393
    #   https://github.com/microsoft/onnxruntime/pull/12394
    # - ONNX/Ort has conflicting registration of proto when linked to shared protobuf.
    #   https://github.com/microsoft/onnxruntime/pull/12440
    # - Downloading archives from GitHub is unreliable.
    PATCHES="json sysonnx abseil jemalloc"
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
        case "$DISTRO_ID-$DISTRO_VERSION_ID" in
        'centos-'* | 'fedora-'* | 'rhel-'* | 'scientific-'*)
            set +xe
            . scl_source enable devtoolset-11 rh-dotnet31 || exit 1
            set -xe
            export AR="$(which gcc-ar)" RANLIB="$(which gcc-ranlib)"
            ;;
        'debian-10' | 'ubuntu-18.'* | 'ubuntu-19.'*)
            export AR="$(which gcc-ar-8)" RANLIB="$(which gcc-ranlib-8)"
            ;;
        'debian-11 '| 'ubuntu-20.'* | 'ubuntu-21.'*)
            export AR="$(which gcc-ar-10)" RANLIB="$(which gcc-ranlib-10)"
            ;;
        *)
            export AR="$(which ar)" RANLIB="$(which ranlib)"
            ;;
        esac

        set +xe
        . "/opt/intel/$([ -e '/opt/intel/oneapi/mkl/latest/env/vars.sh' ] && echo 'oneapi/mkl/latest/env/vars.sh' || echo 'mkl/bin/mklvars.sh')" intel64
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

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
        #   - Dir missing but referenced by install().
        #     https://github.com/microsoft/onnxruntime/issues/5024
        # --------------------------------------------------------
        mkdir -p '../include/onnxruntime/core/providers/shared'
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
            -Donnxruntime_USE_CUDA="$(which nvcc >/dev/null 2>&1 && echo 'ON' || echo 'OFF')"                               \
            -Donnxruntime_USE_DNNL=ON                           \
            -Donnxruntime_USE_EIGEN_FOR_BLAS=ON                 \
            -Donnxruntime_USE_FULL_PROTOBUF=ON                  \
            -Donnxruntime_USE_JEMALLOC=OFF                      \
            -Donnxruntime_USE_LLVM=ON                           \
            -Donnxruntime_USE_MKLML=OFF                         \
            -Donnxruntime_USE_NGRAPH=OFF                        \
            -Donnxruntime_USE_NUPHAR=OFF                        \
            -Donnxruntime_USE_OPENBLAS=OFF                      \
            -Donnxruntime_USE_OPENMP=OFF                        \
            -Donnxruntime_USE_PREINSTALLED_EIGEN=OFF            \
            -Donnxruntime_USE_TENSORRT="$(false && which nvcc >/dev/null 2>&1 && echo 'ON' || echo 'OFF')"                  \
            -Donnxruntime_USE_TVM=OFF                           \
            -G"Ninja"                                           \
            ../cmake

        time "$TOOLCHAIN/cmake" --build .
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
        . "$ROOT_DIR/geo/pip-mirror.sh"
        # ../../rename_manylinux.sh
        # sudo PIP_INDEX_URL="$PIP_INDEX_URL" python3 -m pip install -IU ./*-manylinux1_*.whl
        sudo PIP_INDEX_URL="$PIP_INDEX_URL" python3 -m pip install -IU ./onnxruntime-*-linux_*.whl
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

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/onnxruntime
)
sudo rm -vf $STAGE/ort
sync || true
