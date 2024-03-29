# ================================================================
# Compile TorchVision
# ================================================================

[ -e $STAGE/torchvision ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh"  \
        benjaminp/six                               \
        'pytest-dev/pytest,[3.6=7.0.]'              \
        python-pillow/Pillow,[3.6=8.]               \
        'numpy/numpy,v[3.6=v1.19.|3.7=v1.21.]'

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" pytorch/vision,main
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd vision

    # Known issues:
    # - Torchvision removed the support of Python 3.6 after 0.11.3
    #   https://github.com/pytorch/vision/pull/5161
    case "$DISTRO_ID-$DISTRO_VERSION_ID" in
    'debian-'* | 'linuxmint-'* | 'ubuntu-'*)
        if python3 --version | cut -d' ' -f2 | grep '^3\.[0-6]\.' >/dev/null; then
            git checkout 8c546f6
        fi
        ;;
    esac

    git remote add patch "$GIT_MIRROR/xkszltl/vision.git"
    git fetch patch

    # Known issues:
    #   - Incomplete pyproject.toml can triggers a broken PEP 518 isolated build.
    #     https://github.com/pytorch/vision/issues/4542
    rm -f pyproject.toml
    git commit pyproject.toml -m 'Disable PEP 518 due to the incomplete "pyproject.toml".'

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        set +xe
        . "/opt/intel/$([ -e '/opt/intel/oneapi/mkl/latest/env/vars.sh' ] && echo 'oneapi/mkl/latest/env/vars.sh' || echo 'mkl/bin/mklvars.sh')" intel64
        set -xe

        mkdir -p build
        cd $_

        (
            set -e
            case "$DISTRO_ID-$DISTRO_VERSION_ID" in
            'centos-'* | 'fedora-'* | 'rhel-'* | 'scientific-'*)
                set +xe
                . scl_source enable rh-python38 || exit 1
                set -xe
                ;;
            esac
            # Enabling TensorRT causes crash during cmake generation.
            #     https://github.com/pytorch/pytorch/issues/18524
            "$TOOLCHAIN/cmake"                                  \
                -DCMAKE_BUILD_TYPE=Release                      \
                -DCMAKE_C_COMPILER="$CC"                        \
                -DCMAKE_CXX_COMPILER="$CXX"                     \
                -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache   \
                -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
                -DWITH_CUDA="$(which nvcc >/dev/null 2>&1 && echo 'ON' || echo 'OFF')"          \
                -G"Ninja"                                       \
                ..

            time "$TOOLCHAIN/cmake" --build .
            time "$TOOLCHAIN/cmake" --build . --target install
        )

        (
            set -e
            export FORCE_CUDA="$(! which nvcc >/dev/null 2>&1 || echo '1')"
            export TORCH_CUDA_ARCH_LIST="Pascal;Volta;Turing;Ampere+PTX"
            export PY_VER='^3\.[7-9],^3\.[1-6][0-9]'
            case "$DISTRO_ID-$DISTRO_VERSION_ID" in
            'debian-'* | 'linuxmint-'* | 'ubuntu-'*)
                # Already pinned to a Python3.6-compatible version.
                ! python3 --version | cut -d' ' -f2 | grep '^3\.[0-6]\.' >/dev/null || export PY_VER=''
                ;;
            esac
            "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" ../
        )

        # Exclude GTest/MKL-DNN/ONNX/Caffe files.
        pushd "$INSTALL_ROOT"
        for i in gtest mkl-dnn onnx caffe; do
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
    rm -rf $SCRATCH/vision
)
sudo rm -vf $STAGE/torchvision
sync "$STAGE" || true
