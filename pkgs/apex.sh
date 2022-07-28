# ================================================================
# Compile Nvidia Apex
# ================================================================

[ -e $STAGE/apex ] && ( set -xe
    cd $SCRATCH

    # Known issues:
    # - SciPy 1.8.1 does not work with Cython 0.29.31.
    #   https://github.com/scipy/scipy/issues/16718
    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh"  \
        pypa/packaging                              \
        cython/cython,0.29.30                       \
        yaml/pyyaml                                 \
        'pytest-dev/pytest,[3.6=7.0.]'              \
        'numpy/numpy,v[3.6=v1.19.|3.7=v1.21.]'      \
        afq984/python-cxxfilt,master                \
        docopt/docopt                               \
        tqdm/py-make,v                              \
        tqdm/tqdm,v

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" NVIDIA/apex,master
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd apex

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        # Directly inject args since there is no place for "--global-option".
        mv 'setup.py'{,.bak}
        echo 'import sys' >> 'setup.py'
        echo 'sys.argv.extend(["--cpp_ext"])' >> 'setup.py'
        ! which nvcc >/dev/null || echo 'sys.argv.extend(["--bnp", "--cuda_ext", "--distributed_adam", "--distributed_lamb", "--focal_loss", "--fused_conv_bias_relu", "--transducer", "--xentropy"])' >> 'setup.py'
        cat 'setup.py.bak' >> 'setup.py'
        rm -rf 'setup.py.bak'

        # PyTorch has dropped support for Python 3.6.
        (
            set -e
            export TORCH_CUDA_ARCH_LIST="Pascal;Volta;Turing"
            export PY_VER='^3\.[7-9],^3\.[1-6][0-9]'
            case "$DISTRO_ID-$DISTRO_VERSION_ID" in
            'debian-'* | 'linuxmint-'* | 'ubuntu-'*)
                # Already pinned PyTorch to a Python3.6-compatible version.
                ! python3 --version | cut -d' ' -f2 | grep '^3\.[0-6]\.' >/dev/null || export PY_VER=''
                ;;
            esac
            "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" ./
        )
    )

    cd
    rm -rf $SCRATCH/apex
)
sudo rm -vf $STAGE/apex
sync || true
