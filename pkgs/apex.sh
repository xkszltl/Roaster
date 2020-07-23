# ================================================================
# Compile Nvidia Apex
# ================================================================

[ -e $STAGE/apex ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh"  \
        python/typing                               \
        cython/cython                               \
        yaml/pyyaml                                 \
        pytest-dev/pytest                           \
        afq984/python-cxxfilt,master                \
        docopt/docopt                               \
        tqdm/py-make,v                              \
        tqdm/tqdm,v

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" numpy/numpy,v

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" NVIDIA/apex,master
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd apex

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

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        # Directly inject args since there is no place for "--global-option".
        mv 'setup.py'{,.bak}
        echo 'import sys' >> 'setup.py'
        echo 'sys.argv.extend(["--bnp", "--cpp_ext", "--cuda_ext", "--xentropy"])' >> 'setup.py'
        cat 'setup.py.bak' >> 'setup.py'
        rm -rf 'setup.py.bak'

        "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" ./
    )

    cd
    rm -rf $SCRATCH/apex
)
sudo rm -vf $STAGE/apex
sync || true
