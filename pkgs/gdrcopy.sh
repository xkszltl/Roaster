# ================================================================
# GDRCopy
# ================================================================

[ -e $STAGE/gdrcopy ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" NVIDIA/gdrcopy,v
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd gdrcopy

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-9 || exit 1
            set -xe
            export CC="ccache $(which gcc)" CXX="ccache $(which g++)"
            ;;
        'ubuntu')
            export CC="ccache $(which gcc-8)" CXX="ccache $(which g++-8)"
            ;;
        esac
        export CFLAGS="  $CFLAGS   -O3 -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"
        export CXXFLAGS="$CXXFLAGS -O3 -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"

        export CUDA="$(realpath -e "$(dirname "$(which nvcc)")/..")"

        make CUDA="$CUDA" -j$(nproc)
        make CUDA="$CUDA" PREFIX="$INSTALL_ABS" install -j

        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            packages/build-rpm-packages.sh
            export CC="ccache $(which gcc)" CXX="ccache $(which g++)"
            ;;
        'ubuntu')
            packages/build-deb-packages.sh
            export CC="ccache $(which gcc-8)" CXX="ccache $(which g++-8)"
            ;;
        esac
    )

    false

    # "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/gdrcopy
)
sudo rm -vf $STAGE/gdrcopy
sync || true
