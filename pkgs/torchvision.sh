# ================================================================
# Compile TorchVision
# ================================================================

[ -e $STAGE/torchvision ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh"  \
        benjaminp/six                               \
        python-pillow/Pillow                        \
        numpy/numpy,v1.19.

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" pytorch/vision,main
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd vision

    git remote add patch "$GIT_MIRROR/xkszltl/vision.git"
    git fetch patch

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        mkdir -p build
        cd $_

        # Enabling TensorRT causes crash during cmake generation.
        #     https://github.com/pytorch/pytorch/issues/18524
        "$TOOLCHAIN/cmake"                                  \
            -DCMAKE_BUILD_TYPE=Release                      \
            -DCMAKE_C_COMPILER="$CC"                        \
            -DCMAKE_CXX_COMPILER="$CXX"                     \
            -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache   \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
            -DWITH_CUDA=ON                                  \
            -G"Ninja"                                       \
            ..

        time "$TOOLCHAIN/cmake" --build .
        time "$TOOLCHAIN/cmake" --build . --target install

        (
            set -xe
            export FORCE_CUDA=1
            export TORCH_CUDA_ARCH_LIST="Pascal;Volta;Turing"
            "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" ../
        )

        # Exclude GTest/MKL-DNN/ONNX/Caffe files.
        pushd "$INSTALL_ROOT"
        for i in gtest mkl-dnn onnx caffe; do
            case "$DISTRO_ID" in
            'centos' | 'fedora' | 'rhel')
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
    rm -rf $SCRATCH/vision
)
sudo rm -vf $STAGE/torchvision
sync || true
