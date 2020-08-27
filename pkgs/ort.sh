# ================================================================
# Compile ONNXRuntime
# ================================================================

[ -e $STAGE/ort ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh"  \
        cython/cython                               \
        benjaminp/six                               \
        pytest-dev/pytest                           \
        pycqa/flake8                                \
        numpy/numpy,v

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" Microsoft/onnxruntime,v
    until git clone -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd onnxruntime

    git remote add patch https://github.com/xkszltl/onnxruntime.git

    PATCHES=""

    for i in $PATCHES; do
        git pull --no-edit --rebase patch "$i"
    done

    sed -i 's/FATAL_ERROR\( "Please enable Protobuf_USE_STATIC_LIBS"\)/WARNING\1/' 'cmake/CMakeLists.txt'
    [ ! "$(git diff 'cmake/CMakeLists.txt')" ] || git commit -m 'Suppress Werror for using "libprotobuf.so" in system.' 'cmake/CMakeLists.txt'

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    (
        set -xe

        cd cmake/external

        # rm -rf googletest protobuf
        # cp -rf /usr/local/src/{gtest,protobuf} ./
        # mv gtest googletest

        for i in ./*.cmake; do
            sed -i "s/$(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR_GITHUB")\(\/..*\/.*\.git\)/$(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR")\1/" "$i"
        done
    )

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-8
            set -xe
            export CC="gcc" CXX="g++"
            ;;
        'ubuntu')
            export CC="gcc-8" CXX="g++-8"
            ;;
        esac

        set +xe
        . "/opt/intel/mkl/bin/mklvars.sh" intel64
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
        # --------------------------------------------------------
        cmake                                               \
            -DCMAKE_BUILD_TYPE=Release                      \
            -DCMAKE_C_COMPILER="$CC"                        \
            -DCMAKE_CUDA_FLAGS="-gencode=arch=compute_35,code=sm_35 -gencode=arch=compute_37,code=sm_37"                    \
            -DCMAKE_CXX_COMPILER="$CXX"                     \
            -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache   \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g $($TOOLCHAIN_CPU_NATIVE || echo '-march=haswell -mtune=generic')"  \
            -DCMAKE_{EXE,SHARED}_LINKER_FLAGS='-Xlinker --allow-shlib-undefined'                                            \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
            -DCMAKE_POLICY_DEFAULT_CMP0060=NEW              \
            -DCMAKE_VERBOSE_MAKEFILE=ON                     \
            -DPython_ADDITIONAL_VERSIONS="$(python3 --version | sed -n 's/^Python[[:space:]]*\([0-9]*\.[0-9]*\)\..*/\1/p')" \
            -Deigen_SOURCE_PATH="/usr/local/include/eigen3" \
            -Donnxruntime_BUILD_FOR_NATIVE_MACHINE="$($TOOLCHAIN_CPU_NATIVE && echo 'ON' || echo 'OFF')"                    \
            -Donnxruntime_BUILD_SHARED_LIB=ON               \
            -Donnxruntime_CUDA_HOME="$(readlink -e "$(dirname "$(which nvcc)")/..")"                                        \
            -Donnxruntime_CUDNN_HOME='/usr'                 \
            -Donnxruntime_ENABLE_LANGUAGE_INTEROP_OPS=ON    \
            -Donnxruntime_ENABLE_LTO=OFF                    \
            -Donnxruntime_ENABLE_PYTHON=ON                  \
            -Donnxruntime_PREFER_SYSTEM_LIB=ON              \
            -Donnxruntime_RUN_ONNX_TESTS=ON                 \
            -Donnxruntime_TENSORRT_HOME='/usr'              \
            -Donnxruntime_USE_CUDA=ON                       \
            -Donnxruntime_USE_DNNL=ON                       \
            -Donnxruntime_USE_EIGEN_FOR_BLAS=ON             \
            -Donnxruntime_USE_FULL_PROTOBUF=ON              \
            -Donnxruntime_USE_JEMALLOC=OFF                  \
            -Donnxruntime_USE_LLVM=ON                       \
            -Donnxruntime_USE_MKLML=ON                      \
            -Donnxruntime_USE_NGRAPH=OFF                    \
            -Donnxruntime_USE_NUPHAR=OFF                    \
            -Donnxruntime_USE_OPENBLAS=OFF                  \
            -Donnxruntime_USE_OPENMP=OFF                    \
            -Donnxruntime_USE_PREINSTALLED_EIGEN=OFF        \
            -Donnxruntime_USE_TENSORRT=ON                   \
            -Donnxruntime_USE_TVM=OFF                       \
            -G"Ninja"                                       \
            ../cmake

        time cmake --build .
        time cmake --build . --target install

        # Work around https://github.com/microsoft/onnxruntime/issues/4729
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            find . -maxdepth 1 -name '*\.so' -or -name '*\.so\.*' | xargs cp -dnrt "$INSTALL_ABS/lib64/"
            ;;
        'ubuntu')
            find . -maxdepth 1 -name '*\.so' -or -name '*\.so\.*' | xargs cp -dnrt "$INSTALL_ABS/lib/"
            ;;
        esac

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
                time cmake --build . --target test || ! nvidia-smi
            fi
        fi

        python3 ../setup.py bdist_wheel
        pushd dist
        # ../../rename_manylinux.sh
        # sudo python3 -m pip install -IU ./*-manylinux1_*.whl
        sudo python3 -m pip install -IU ./onnxruntime-*-linux_*.whl
        popd

        # Exclude MKL-DNN/ONNX files.
        pushd "$INSTALL_ROOT"
        for i in mkl-dnn onnx; do
            case "$DISTRO_ID" in
            'centos' | 'fedora' | 'rhel')
                [ "$(rpm -qa "roaster-$i")" ] || continue
                rpm -ql "roaster-$i" | sed -n 's/^\//\.\//p' | xargs rm -rf
                ;;
            'ubuntu')
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
