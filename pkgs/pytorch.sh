# ================================================================
# Compile PyTorch/Caffe2
# ================================================================

[ -e $STAGE/pytorch ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" python/typing numpy/numpy,v benjaminp/six yaml/pyyaml pytest-dev/pytest Frozenball/pytest-sugar,master

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" pytorch/pytorch,master
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd pytorch
    git checkout 38aa5a5

    git remote add patch https://github.com/xkszltl/pytorch.git

    PATCHES="lstm"

    git pull --no-edit patch $PATCHES

    # for i in $PATCHES; do
    #     git pull --no-edit --rebase patch "$i"
    # done

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    if [ -d '/usr/local/src/mkl-dnn' ]; then
        echo 'Use locally installed MKL-DNN.'
        ln -sf '/usr/local/src/mkl-dnn' third_party/ideep/mkl-dnn
    fi

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

        # Enabling TensorRT causes crash during cmake generation.
        #     https://github.com/pytorch/pytorch/issues/18524
        cmake                                               \
            -DATEN_NO_TEST=ON                               \
            -DBLAS=MKL                                      \
            -DBUILD_BINARY=ON                               \
            -DBUILD_CUSTOM_PROTOBUF=OFF                     \
            -DBUILD_SHARED_LIBS=ON                          \
            -DBUILD_TEST=ON                                 \
            -DCMAKE_BUILD_TYPE=Release                      \
            -DCMAKE_C_COMPILER="$CC"                        \
            -DCMAKE_CXX_COMPILER="$CXX"                     \
            -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache   \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g $($TOOLCHAIN_CPU_NATIVE || echo '-march=haswell')" \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
            -DCMAKE_POLICY_DEFAULT_CMP0003=NEW              \
            -DCMAKE_POLICY_DEFAULT_CMP0060=NEW              \
            -DCMAKE_VERBOSE_MAKEFILE=ON                     \
            -DCPUINFO_BUILD_TOOLS=ON                        \
            -DINSTALL_TEST=ON                               \
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

        # Currently there is a bug causing the second run of cmake to fail when finding python.
        # Probably because PYTHON_* variables are partially cached.
        # This may be a cmake bug.

        # time cmake --build . --target rebuild_cache
        # time cmake --build . --target
        time cmake --build . --target install

        time cmake --build . --target test || ! nvidia-smi

        # python3 -m pytest --disable-warnings -v caffe2/python

        # Exclude GTest/MKL-DNN/ONNX/Caffe files.
        pushd "$INSTALL_ROOT"
        for i in gtest mkl-dnn onnx caffe; do
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
