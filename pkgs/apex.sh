# ================================================================
# Compile Nvidia Apex
# ================================================================

[ -e $STAGE/apex ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh"  \
        pypa/packaging                              \
        cython/cython                               \
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

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        # Directly inject args since there is no place for "--global-option".
        mv 'setup.py'{,.bak}
        echo 'import sys' >> 'setup.py'
        echo 'sys.argv.extend(["--cpp_ext"])' >> 'setup.py'
        ! which nvcc >/dev/null || echo 'sys.argv.extend(["--bnp", "--cuda_ext", "--xentropy"])' >> 'setup.py'
        cat 'setup.py.bak' >> 'setup.py'
        rm -rf 'setup.py.bak'

        # PyTorch has dropped support for Python 3.6.
        PY_VER='^3\.[7-9],^3\.[1-6][0-9]' TORCH_CUDA_ARCH_LIST="Pascal;Volta;Turing" "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" ./
    )

    cd
    rm -rf $SCRATCH/apex
)
sudo rm -vf $STAGE/apex
sync || true
