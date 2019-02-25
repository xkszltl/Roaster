# ================================================================
# Compile Caffe2
# ================================================================

[ -e $STAGE/caffe2 ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" python/typing enum34 numpy/numpy,v benjaminp/six yaml/pyyaml pytest-dev/pytest Frozenball/pytest-sugar,v

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" pytorch/pytorch,master
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd pytorch

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
        set +xe
        . scl_source enable devtoolset-7 rh-python36
        # . "/opt/intel/mkl/bin/mklvars.sh" intel64
        # . /opt/intel/tbb/bin/tbbvars.sh intel64
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        export MPI_HOME=/usr/local/openmpi

        cmake                                               \
            -DATEN_NO_TEST=ON                               \
            -DBLAS=MKL                                      \
            -DBUILD_CUSTOM_PROTOBUF=OFF                     \
            -DBUILD_SHARED_LIBS=ON                          \
            -DBUILD_TEST=ON                                 \
            -DCMAKE_BUILD_TYPE=Release                      \
            -DCMAKE_C_COMPILER=gcc                          \
            -DCMAKE_CXX_COMPILER=g++                        \
            -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache   \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
            -DCMAKE_POLICY_DEFAULT_CMP0003=NEW              \
            -DCMAKE_POLICY_DEFAULT_CMP0060=NEW              \
            -DCMAKE_VERBOSE_MAKEFILE=ON                     \
            -DCPUINFO_BUILD_TOOLS=ON                        \
            -DINSTALL_TEST=ON                               \
            -DTORCH_CUDA_ARCH_LIST="Pascal;Volta"           \
            -DUSE_GFLAGS=ON                                 \
            -DUSE_GLOG=ON                                   \
            -DUSE_LEVELDB=ON                                \
            -DUSE_LMDB=ON                                   \
            -DUSE_MKLDNN=ON                                 \
            -DUSE_NATIVE_ARCH=ON                            \
            -DUSE_OBSERVERS=ON                              \
            -DUSE_OPENCV=ON                                 \
            -DUSE_OPENMP=ON                                 \
            -DUSE_PROF=ON                                   \
            -DUSE_ROCKSDB=ON                                \
            -DUSE_SYSTEM_EIGEN_INSTALL=ON                   \
            -DUSE_SYSTEM_NCCL=ON                            \
            -DUSE_TENSORRT=ON                               \
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

        # python -m pytest --disable-warnings -v caffe2/python

        # Exclude GTest/MKL-DNN/ONNX/Caffe files.
        pushd "$INSTALL_ROOT"
        for i in gtest mkl-dnn onnx caffe; do
            [ "$(rpm -qa "codingcafe-$i")" ] || continue
            rpm -ql "codingcafe-$i" | sed -n 's/^\//\.\//p' | xargs rm -rf
        done
        popd

        # --------------------------------------------------------
        # Install python files
        # --------------------------------------------------------
        # for ver in 2.7 3.4; do
        #     parallel --group -j0 'bash -c '"'"'
        #         set -e
        #         install -D {,"'"$INSTALL_ROOT/usr/local/lib/python$ver/"'"}"{}"
        #     '"'" ::: $(find caffe2/python -name '*.py')
        # done

        # --------------------------------------------------------
        # Tag with version detected from cmake cache
        # --------------------------------------------------------

        VER_FILE='../caffe2/VERSION_NUMBER'
        if [ -e "$VER_FILE" ] && [ "$(sed -n '/^[[:space:]]*[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/p' "$VER_FILE")" ]; then
            sed -n 's/^[[:space:]]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' "$VER_FILE" | head -n1
        else
            sed -n 's/^set[[:space:]]*([[:space:]]*CAFFE2_VERSION_.....[[:space:]][[:space:]]*\([0-9]*\)[[:space:]]*).*/\1/p' ../CMakeLists.txt | paste -sd.
        fi | xargs git tag -f

        # --------------------------------------------------------
        # Relocate site-package installation.
        # --------------------------------------------------------
        mkdir -p "$(readlink -m "$INSTALL_ROOT/$(dirname "$(which python)")/../lib/python$(python --version 2>&1 | sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n1)/site-packages")"
        mv -f {"$INSTALL_ABS","$(readlink -m "$INSTALL_ROOT/$(dirname "$(which python)")/..")"}"/lib/python$(python --version 2>&1 | sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n1)/site-packages/caffe2"
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"
    
    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/pytorch
)
sudo rm -vf $STAGE/caffe2
sync || true
