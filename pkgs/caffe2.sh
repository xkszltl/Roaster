# ================================================================
# Compile Caffe2
# ================================================================

[ -e $STAGE/caffe2 ] && ( set -e
    cd $SCRATCH

    # ------------------------------------------------------------

    until git clone --depth 1 $GIT_MIRROR/caffe2/caffe2.git; do echo 'Retrying'; done
    cd caffe2

    if [ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ]; then
        export HTTP_PROXY=proxy.codingcafe.org:8118
        [ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
        [ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
        [ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY
        for i in facebook{,incubator} glog google Maratyszcza NervanaSystems nvidia NVlabs pybind RLovelett zdevito; do
            sed -i "s/[^[:space:]]*:\/\/[^\/]*\(\/$i\/.*\)/$(sed 's/\//\\\//g' <<<$GIT_MIRROR )\1.git/" .gitmodules
            sed -i "s/\($(sed 's/\//\\\//g' <<<$GIT_MIRROR )\/$i\/.*\.git\)\.git[[:space:]]*$/\1/" .gitmodules
        done
    fi

    git submodule init
    until git config --file .gitmodules --get-regexp path | cut -d' ' -f2 | parallel -j0 --ungroup --bar 'git submodule update --recursive {}'; do echo 'Retrying'; done

    # ------------------------------------------------------------

    mkdir -p build
    cd $_

    ( set -e
        # Currently caffe2 can only be built with gcc-5.
        # CUDA 9.1 only support up to gcc-6.3.0 while devtoolset-6 contains gcc-6.3.1
        # TODO: Upgrade glog to use new compiler when possible.
        . scl_source enable devtoolset-4 || true

        ln -sf $(which ninja-build) /usr/bin/ninja

        export MPI_HOME=/usr/local/openmpi

        # Some platform may need -DCUDA_ARCH_NAME=Pascal
        cmake                                                   \
            -GNinja                                             \
            -DCMAKE_BUILD_TYPE=Release                          \
            -DCMAKE_C{,XX}_FLAGS="-g"                           \
            -DCMAKE_VERBOSE_MAKEFILE=ON                         \
            -DBENCHMARK_ENABLE_LTO=ON                           \
            -DBENCHMARK_USE_LIBCXX=OFF                          \
            -DBLAS=MKL                                          \
            -DUSE_ATEN=ON                                       \
            -DUSE_NATIVE_ARCH=ON                                \
            -DUSE_OPENMP=ON                                     \
            -DUSE_ZMQ=ON                                        \
            -DUSE_ZSTD=OFF                                      \
            ..

        time cmake --build .
        nvidia-smi && time cmake --build . --target test || true
        time cmake --build . --target install

        rm -rf /usr/bin/ninja
    )

    for i in /usr/lib/python*/site-packages; do
    for j in caffe{,2}; do
        ln -sf /usr/local/$j $i/$j &
    done
    done

    echo '/usr/local/lib' > /etc/ld.so.conf.d/caffe2.conf
    ldconfig &
    $IS_CONTAINER && ccache -C &
    cd
    rm -rf $SCRATCH/caffe2
    wait

    parallel -j0 --bar --line-buffer 'bash -c '"'"'
        python -m caffe2.python.models.download -f -i {}
    '"'" :::                                        \
        bvlc_{alexnet,googlenet,reference_caffenet} \
        finetune_flickr_style                       \
        shufflenet                                  \
        squeezenet
)
rm -rvf $STAGE/caffe2
sync || true
