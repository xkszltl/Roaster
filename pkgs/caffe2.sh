# ================================================================
# Compile Caffe2
# ================================================================

[ -e $STAGE/caffe2 ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    until git clone $GIT_MIRROR/pytorch/pytorch.git; do echo 'Retrying'; done
    cd pytorch

    git remote add patch https://github.com/xkszltl/pytorch.git
    git fetch patch

    PATCHES="pybind redef observer typeid gcc7"
    # PATCHES="$PATCHES gpu_dll"

    for i in $PATCHES; do
        git checkout "$i"
        git rebase master
    done
    git checkout master
    for i in $PATCHES; do
        git pull --no-edit patch "$i"
    done

    if [ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ]; then
        export HTTP_PROXY=proxy.codingcafe.org:8118
        [ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
        [ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
        [ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY
        for i in 01org ARM-software benjaminp catchorg USCiLab eigenteam facebook{,incubator} google intel Maratyszcza nanopb NervanaSystems nvidia NVlabs onnx pybind shibatch; do
            sed -i "s/[^[:space:]]*:\/\/[^\/]*\(\/$i\/.*\)/$(sed 's/\//\\\//g' <<<$GIT_MIRROR )\1.git/" .gitmodules
            sed -i "s/\($(sed 's/\//\\\//g' <<<$GIT_MIRROR )\/$i\/.*\.git\)\.git[[:space:]]*$/\1/" .gitmodules
        done
    fi

    git submodule init
    until git config --file .gitmodules --get-regexp path | cut -d' ' -f2 | parallel -j0 --ungroup --bar '[ ! -d "{}" ] || git submodule update --recursive "{}"'; do echo 'Retrying'; done

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        # . /opt/intel/tbb/bin/tbbvars.sh intel64
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        # ln -sf $(which ninja-build) /usr/bin/ninja

        export MPI_HOME=/usr/local/openmpi

        cmake                                       \
            -DBENCHMARK_ENABLE_LTO=ON               \
            -DBENCHMARK_USE_LIBCXX=OFF              \
            -DBLAS=MKL                              \
            -DBUILD_CUSTOM_PROTOBUF=OFF             \
            -DBUILD_SHARED_LIBS=ON                  \
            -DBUILD_TEST=ON                         \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER=gcc                  \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-g"               \
            -DCMAKE_CXX_COMPILER=g++                \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DCMAKE_VERBOSE_MAKEFILE=ON             \
            -DCPUINFO_BUILD_TOOLS=ON                \
            -DCUDA_ARCH_NAME=All                    \
            -DINSTALL_TEST=ON                       \
            -DUSE_ATEN=OFF                          \
            -DUSE_MKLDNN=ON                         \
            -DUSE_NATIVE_ARCH=ON                    \
            -DUSE_OBSERVERS=ON                      \
            -DUSE_OPENMP=ON                         \
            -DUSE_ROCKSDB=ON                        \
            -DUSE_SYSTEM_NCCL=ON                    \
            -DUSE_ZMQ=ON                            \
            -DUSE_ZSTD=OFF                          \
            -G"Ninja"                               \
            ..

        time cmake --build .
        time cmake --build . --target test || ! nvidia-smi
        time cmake --build . --target install

        # rm -rf /usr/bin/ninja

        # --------------------------------------------------------
        # Tag with version detected from cmake cache
        # --------------------------------------------------------

        sed -n 's/^set[[:space:]]*([[:space:]]*CAFFE2_VERSION_.....[[:space:]][[:space:]]*\([0-9]*\)[[:space:]]*).*/\1/p' ../CMakeLists.txt | paste -sd. | xargs git tag -f

        # --------------------------------------------------------
        # Avoid caffe conflicts
        # --------------------------------------------------------

        rm -rf "$INSTALL_ROOT/usr/local/include/caffe/proto"
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"
    
    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/pytorch

    # ------------------------------------------------------------

    $ISCONTAINER || parallel -j0 --bar --line-buffer 'bash -c '"'"'
        echo N | python -m caffe2.python.models.download -i {}
    '"'" :::                    \
        bvlc_{alexnet,googlenet,reference_{caffenet,rcnn_ilsvrc13}} \
        densenet121             \
        finetune_flickr_style   \
        inception_v{1,2}        \
        resnet50                \
        shufflenet              \
        squeezenet              \
        vgg{16,19}
)
sudo rm -vf $STAGE/caffe2
sync || true
