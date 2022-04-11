# ================================================================
# Compile PyTorch/Caffe2
# ================================================================

[ -e $STAGE/pytorch ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh"          \
        pypa/packaging                                      \
        cython/cython                                       \
        benjaminp/six                                       \
        yaml/pyyaml                                         \
        'pytest-dev/pytest,[3.6=7.0.]'                      \
        Frozenball/pytest-sugar,master                      \
        'numpy/numpy,v[3.6=v1.19.|3.7=v1.21.]'              \
        'scipy/scipy,v[3.6=v1.5.|3.7=v1.7.]'                \
        'networkx/networkx,networkx-[3.6=networkx-2.5.]'    \
        micheles/decorator
    case "$(python3 --version | cut -d' ' -f2 | cut -d. -f-2)" in
    '3.6')
        "$ROOT_DIR/pkgs/utils/pip_install_from_wheel.sh" dataclasses
        ;;
    esac

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" pytorch/pytorch,master
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd pytorch

    # Known issues:
    # - PyTorch 1.11 dropped support for Python 3.6.
    #   https://github.com/pytorch/pytorch/pull/70493
    # - PyTorch 1.10 only supports up to CUDA 11.4.
    #   https://discuss.pytorch.org/t/compiling-1-10-1-from-source-with-gcc-11-and-cuda-11-5/140971
    #   While it is fixed in master, that requires Python 3.7 not available everywhere.
    #   https://github.com/pytorch/pytorch/pull/66219
    # - Always pin to 025cd69 for now due to a recent build issue:
    #   https://github.com/pytorch/pytorch/issues/73074
    if python3 --version | cut -d' ' -f2 | grep '^3\.[0-6]\.' >/dev/null; then
        git checkout 025cd69
        # Patch RNN in memonger.
        # - https://github.com/pytorch/pytorch/pull/24388
        # - https://github.com/pytorch/pytorch/pull/74031
        git cherry-pick adae0d35 198d727d
    fi

    git remote add patch "$GIT_MIRROR/xkszltl/pytorch.git"

    PATCHES="lstm std"
    for i in $PATCHES; do
        git fetch patch "$i"
        git cherry-pick FETCH_HEAD
    done

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    if [ -d '/usr/local/src/mkl-dnn' ]; then
        echo 'Use locally installed MKL-DNN.'
        ln -sf '/usr/local/src/mkl-dnn' third_party/ideep/mkl-dnn
    fi

    # Use latest NCCL since it is referenced regardless of USE_SYSTEM_NCCL.
    (
        set -xe
        pushd third_party/nccl/nccl
        . "$ROOT_DIR/pkgs/utils/git/version.sh" NVIDIA/nccl,v
        git checkout "$GIT_TAG"
        popd
    )

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        set +xe
        # . "/opt/intel/$([ -e '/opt/intel/oneapi/mkl/latest/env/vars.sh' ] && echo 'oneapi/mkl/latest/env/vars.sh' || echo 'mkl/bin/mklvars.sh')" intel64
        # . "/opt/intel/$([ -e '/opt/intel/oneapi/tbb/latest/env/vars.sh' ] && echo 'oneapi/tbb/latest/env/vars.sh' || echo 'tbb/bin/tbbvars.sh')" intel64
        set -xe

        mkdir -p build
        cd $_

        export MPI_HOME=/usr/local/openmpi

        # PyTorch still uses "FindCUDA.cmake" so CMAKE_CUDA_COMPILER_LAUNCHER does not work.
        # And seems only env var works based on the following code:
        #     https://github.com/Kitware/CMake/blob/512ab500f06d6c645985cc8014c5e6291b9a059f/Modules/FindCUDA.cmake#L756-L769
        # Note this may conflict with CMAKE_CUDA_COMPILER_LAUNCHER when PyTorch switch to that.
        export CUDA_NVCC_EXECUTABLE="$TOOLCHAIN/nvcc"

        (
            set -e
            case "$DISTRO_ID-$DISTRO_VERSION_ID" in
            'centos-'* | 'fedora-'* | 'rhel-'* | 'scientific-'*)
                set +xe
                . scl_source enable rh-python38 || exit 1
                set -xe
                ;;
            esac

            # Known issues:
            #   - Enabling TensorRT causes crash during cmake generation.
            #     https://github.com/pytorch/pytorch/issues/18524
            #   - Somehow gloo fails to detect NCCL without NCCL_INCLUDE_DIR.
            #   - Currently there is a bug causing the second run of cmake to fail when finding python.
            #     Probably because PYTHON_* variables are partially cached.
            #     This may be a cmake bug.
            #     https://github.com/pytorch/pytorch/issues/43030
            #   - C++ 17 is required for RocksDB 7.
            ONESHOT=false
            for i in $(seq 2); do
                NCCL_ROOT_DIR='/usr'                                \
                "$TOOLCHAIN/cmake"                                  \
                    -DATEN_NO_TEST=ON                               \
                    -DBLAS=MKL                                      \
                    -DBUILD_BINARY=ON                               \
                    -DBUILD_CAFFE2=ON                               \
                    -DBUILD_CUSTOM_PROTOBUF=OFF                     \
                    -DBUILD_PYTHON=ON                               \
                    -DBUILD_SHARED_LIBS=ON                          \
                    -DBUILD_TEST=ON                                 \
                    -DCMAKE_BUILD_TYPE=Release                      \
                    -DCMAKE_C_COMPILER="$CC"                        \
                    -DCMAKE_{CUDA_HOST,CXX}_COMPILER="$CXX"         \
                    -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache   \
                    -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g1 $($TOOLCHAIN_CPU_NATIVE || echo '-march=haswell -mtune=generic')"  \
                    -DCMAKE_CXX_STANDARD=17                         \
                    -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
                    $([ -e '/opt/intel/oneapi/compiler/latest/env/vars.sh' ] && echo -DINTEL_COMPILER_DIR="/opt/intel/oneapi/compiler/latest")  \
                    $([ -e '/opt/intel/oneapi/mkl/latest/env/vars.sh'      ] && echo -DINTEL_{MKL,OMP}_DIR="/opt/intel/oneapi/mkl/latest")      \
                    -DCMAKE_POLICY_DEFAULT_CMP0003=NEW              \
                    -DCMAKE_POLICY_DEFAULT_CMP0060=NEW              \
                    -DCMAKE_VERBOSE_MAKEFILE=ON                     \
                    -DCPUINFO_BUILD_TOOLS=ON                        \
                    -D{DNNL,MKLDNN}_LIBRARY_TYPE='SHARED'           \
                    -DINSTALL_TEST=ON                               \
                    -DNCCL_INCLUDE_DIR='/usr/include'               \
                    -DNCCL_ROOT='/usr/'                             \
                    -DNCCL_ROOT_DIR='/usr/'                         \
                    -DPYTHON_EXECUTABLE="$(which python3)"          \
                    -DTORCH_CUDA_ARCH_LIST="Pascal;Volta;Turing"    \
                    -DUSE_FBGEMM=ON                                 \
                    -DUSE_GFLAGS=ON                                 \
                    -DUSE_GLOG=ON                                   \
                    -DUSE_LEVELDB=ON                                \
                    -DUSE_LMDB=ON                                   \
                    -DUSE_MKLDNN=ON                                 \
                    -DUSE_NATIVE_ARCH="$($TOOLCHAIN_CPU_NATIVE && echo ON || echo OFF)" \
                    -DUSE_OBSERVERS=ON                              \
                    -DUSE_OPENCV=ON                                 \
                    -DUSE_OPENMP=ON                                 \
                    -DUSE_PROF=ON                                   \
                    -DUSE_ROCKSDB=ON                                \
                    -DUSE_SYSTEM_EIGEN_INSTALL=ON                   \
                    -DUSE_SYSTEM_NCCL=ON                            \
                    -DUSE_TENSORRT=OFF                              \
                    -DUSE_ZMQ=ON                                    \
                    -DUSE_ZSTD=OFF                                  \
                    -DWITH_BLAS=mkl                                 \
                    -G"Ninja"                                       \
                    ..
                grep '^BUILD_PYTHON:BOOL=ON' CMakeCache.txt
                ! $ONESHOT || break
                time "$TOOLCHAIN/cmake" --build . --target rebuild_cache
                grep '^BUILD_PYTHON:BOOL=ON' CMakeCache.txt
            done
            $ONESHOT || time "$TOOLCHAIN/cmake" --build . --target rebuild_cache
            grep '^BUILD_PYTHON:BOOL=ON' CMakeCache.txt

            # Work around missing TensorBody.h issue:
            # - https://github.com/pytorch/pytorch/issues/69360
            time "$TOOLCHAIN/cmake" --build . --target 'aten/src/ATen/core/TensorBody.h'

            $ONESHOT || time "$TOOLCHAIN/cmake" --build .
            time "$TOOLCHAIN/cmake" --build . --target install
            grep '^BUILD_PYTHON:BOOL=ON' CMakeCache.txt

            time "$TOOLCHAIN/ctest" --output-on-failure -j"$(nproc)" || ! nvidia-smi
        )

        # Known issues:
        #   - setup.py assumes lib installed in-source:
        #     See https://github.com/pytorch/pytorch/issues/43113
        #   - Set LDFLAGS for "-ltorch_python", or pip will fail with build_ext and restart, deleting all cached CMake options.
        #     This may be fixed if we install libs in-source, but we have not checked.
        mkdir -p '../torch'
        cp -rvf "$INSTALL_ABS"/* "../torch/"
        LDFLAGS="-L'$(pwd)/lib'" NCCL_ROOT_DIR='/usr/' PY_VER='^3\.[7-9],^3\.[1-6][0-9]' "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" ..

        # Dirty hack to fix torchvision build issues.
        # for site in {"/usr/local/lib64/python3.6","/opt/rh/rh-python38/root/usr/lib64/python3.8"}/{dist,site}"-packages/torch"; do
        for site in "/usr/local/lib/python$(python3 --version 2>&1 | sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n1)/"{dist,site}"-packages/torch"; do
            [ -d "$site" ] || continue
            for target in 'bin/torch_shm_manager' 'include/torch' 'lib'; do
                sudo mkdir -p "$(dirname "$site/./$target")"
                sudo ln -sf {'/usr/local',"$site"}"/$target"
            done
        done

        # python3 -m pytest --disable-warnings -v caffe2/python

        # Exclude GTest/MKL-DNN/ONNX/Caffe files.
        pushd "$INSTALL_ROOT"
        for i in caffe gtest mkl-dnn onnx openblas pybind11; do
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
        rm -rf ./usr/local/lib*/libgtest*
        rm -rf ./usr/local/include/gtest
        popd

        # --------------------------------------------------------
        # Install python files
        # --------------------------------------------------------
        # for ver in 3.6; do
        #     parallel --group -j0 'bash -c '"'"'
        #         set -e
        #         install -D {,"'"$INSTALL_ROOT/usr/local/lib/python$ver/"'"}"{}"
        #     '"'" ::: $(find caffe2/python -name '*.py')
        # done

        # --------------------------------------------------------
        # Relocate site-package installation.
        # --------------------------------------------------------
        (
            set -e
            case "$DISTRO_ID-$DISTRO_VERSION_ID" in
            'centos-'* | 'fedora-'* | 'rhel-'* | 'scientific-'*)
                set +xe
                . scl_source enable rh-python38 || exit 1
                set -xe
                ;;
            esac
            PY_SITE_PKGS_SRC_DIR="lib/python$(python3 --version 2>&1 | sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n1)/site-packages"
            PY_SITE_PKGS_DST_DIR="$PY_SITE_PKGS_SRC_DIR"
            case "$DISTRO_ID" in
            'debian' | 'linuxmint' | 'ubuntu')
                # PyTorch is moving away from distutils.
                # - https://github.com/pytorch/pytorch/pull/57040
                # Version before that install to dist-packages.
                # Version afterward should be relocated to dist-packages for visibility of Debian Python.
                [ -d "$INSTALL_ABS/$PY_SITE_PKGS_SRC_DIR/caffe2" ] && PY_SITE_PKGS_DST_DIR="$(realpath -m "$PY_SITE_PKGS_SRC_DIR/../dist-packages")" || PY_SITE_PKGS_SRC_DIR='lib/python3/dist-packages'
                ;;
            esac
            mkdir -p "$(realpath -m "$INSTALL_ROOT/$(dirname "$(which python3)")/../$PY_SITE_PKGS_DST_DIR")"
            mv -f {"$INSTALL_ABS/$PY_SITE_PKGS_SRC_DIR","$(realpath -m "$INSTALL_ROOT/$(dirname "$(which python3)")/../$PY_SITE_PKGS_DST_DIR")"}'/caffe2'
        )
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/pytorch
)
sudo rm -vf $STAGE/pytorch
sync || true
