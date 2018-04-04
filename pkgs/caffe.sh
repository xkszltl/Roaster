# ================================================================
# Compile Caffe
# ================================================================

[ -e $STAGE/caffe ] && ( set -xe
    cd $SCRATCH

    until git clone --depth 1 $GIT_MIRROR/BVLC/caffe.git; do echo 'Retrying'; done
    cd caffe

    # ------------------------------------------------------------
    # Version assignment
    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +x
        . scl_source enable devtoolset-6 || true
        set -xe

        mkdir -p build
        cd $_

        # CUDA 9.x has removed Fermi (2.x) support.
        # Use CUDA_ARCH_NAME to fix compile error "Unsupported gpu architecture 'compute_20'".
        cmake                                       \
            -G"Ninja"                               \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C{,XX}_FLAGS="-g"               \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DCMAKE_VERBOSE_MAKEFILE=ON             \
            -DCUDA_ARCH_NAME=Auto                   \
            -DBLAS=MKL                              \
            -DUSE_NCCL=ON                           \
            ..

        time cmake --build .
        time cmake --build . --target runtest || ! nvidia-smi
        time cmake --build . --target install

        # --------------------------------------------------------
        # Tag with version detected from cmake cache
        # --------------------------------------------------------

        cmake -LA -N . | sed -n 's/^CAFFE_TARGET_VERSION:.*=//p' | xargs git tag -f
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"
    
    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/caffe
)
sudo rm -vf $STAGE/caffe
sync || true
