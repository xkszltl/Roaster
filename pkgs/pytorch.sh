# ================================================================
# Compile PyTorch/Caffe2
# ================================================================

[ -e $STAGE/pytorch ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh"  \
        python/typing                               \
        cython/cython                               \
        benjaminp/six                               \
        yaml/pyyaml                                 \
        pytest-dev/pytest                           \
        Frozenball/pytest-sugar,master              \
        numpy/numpy,v                               \
        micheles/decorator                          \
        networkx/networkx,networkx-

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" pytorch/pytorch,master
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd pytorch

    git remote add patch https://github.com/xkszltl/pytorch.git

    PATCHES="lstm rnn_arg"

    git pull --no-edit patch $PATCHES

    # for i in $PATCHES; do
    #     git pull --no-edit --rebase patch "$i"
    # done

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
        # . "/opt/intel/mkl/bin/mklvars.sh" intel64
        # . /opt/intel/tbb/bin/tbbvars.sh intel64
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        export MPI_HOME=/usr/local/openmpi

        # PyTorch still uses "FindCUDA.cmake" so CMAKE_CUDA_COMPILER_LAUNCHER does not work.
        # And seems only env var works based on the following code:
        #     https://github.com/Kitware/CMake/blob/512ab500f06d6c645985cc8014c5e6291b9a059f/Modules/FindCUDA.cmake#L756-L769
        # Note this may conflict with CMAKE_CUDA_COMPILER_LAUNCHER when PyTorch switch to that.
        export CUDA_NVCC_EXECUTABLE="$TOOLCHAIN/nvcc"

        # Known issues:
        #   - Enabling TensorRT causes crash during cmake generation.
        #     https://github.com/pytorch/pytorch/issues/18524
        #   - Somehow gloo fails to detect NCCL without NCCL_INCLUDE_DIR.
        #   - Currently there is a bug causing the second run of cmake to fail when finding python.
        #     Probably because PYTHON_* variables are partially cached.
        #     This may be a cmake bug.
        for i in $(seq 2); do
            NCCL_ROOT_DIR='/usr'                                \
            cmake                                               \
                -DATEN_NO_TEST=ON                               \
                -DBLAS=MKL                                      \
                -DBUILD_BINARY=ON                               \
                -DBUILD_CUSTOM_PROTOBUF=OFF                     \
                -DBUILD_PYTHON=ON                               \
                -DBUILD_SHARED_LIBS=ON                          \
                -DBUILD_TEST=ON                                 \
                -DCMAKE_BUILD_TYPE=Release                      \
                -DCMAKE_C_COMPILER="$CC"                        \
                -DCMAKE_CXX_COMPILER="$CXX"                     \
                -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache   \
                -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g $($TOOLCHAIN_CPU_NATIVE || echo '-march=haswell -mtune=generic')"  \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
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
                -DTORCH_CUDA_ARCH_LIST="Pascal;Volta"           \
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
        done
        time cmake --build . --target rebuild_cache
        time cmake --build . --target rebuild_cache
        grep '^BUILD_PYTHON:BOOL=ON' CMakeCache.txt

        time cmake --build . --target
        time cmake --build . --target install
        CTEST_PARALLEL_LEVEL="$(nproc)" time cmake --build . --target test || ! nvidia-smi

        # Known issues:
        #   - Set LDFLAGS for "-ltorch_python", or pip will fail with build_ext and restart, deleting all cached CMake options.
        LDFLAGS="-L'$(pwd)/lib'" NCCL_ROOT_DIR='/usr/' "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" ..

        # Dirty hack to fix torchvision build issues.
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            # for site in {"/usr/local/lib64/python3.6","/opt/rh/rh-python38/root/usr/lib64/python3.8"}"/site-packages/torch"; do
            for site in "/usr/local/lib64/python3.6/site-packages/torch"; do
                for target in bin/torch_shm_manager include/torch lib; do
                    sudo mkdir -p "$(dirname "$site/./$target")"
                    sudo ln -sf {'/usr/local',"$site"}"/$target"
                done
            done
            ;;
        'ubuntu')
            for site in "/usr/local/lib/python3.6/dist-packages/torch"; do
                for target in bin/torch_shm_manager include/torch lib; do
                    sudo mkdir -p "$(dirname "$site/./$target")"
                    sudo ln -sf {'/usr/local',"$site"}"/$target"
                done
            done
            ;;
        esac

        # python3 -m pytest --disable-warnings -v caffe2/python

        # Exclude GTest/MKL-DNN/ONNX/Caffe files.
        pushd "$INSTALL_ROOT"
        for i in caffe gtest mkl-dnn onnx openblas pybind11; do
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
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            PY_SITE_PKGS_DIR="lib/python$(python3 --version 2>&1 | sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n1)/site-packages"
            ;;
        'ubuntu')
            PY_SITE_PKGS_DIR="lib/python3/dist-packages"
            ;;
        esac
        mkdir -p "$(readlink -m "$INSTALL_ROOT/$(dirname "$(which python3)")/../$PY_SITE_PKGS_DIR")"
        mv -f {"$INSTALL_ABS","$(readlink -m "$INSTALL_ROOT/$(dirname "$(which python3)")/..")"}"/$PY_SITE_PKGS_DIR/caffe2"
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"
    
    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/pytorch
)
sudo rm -vf $STAGE/pytorch
sync || true
