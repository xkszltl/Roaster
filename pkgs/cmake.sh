# ================================================================
# Install CMake
# ================================================================

[ -e $STAGE/cmake ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" Kitware/CMake,v
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO" cmake; do echo 'Retrying'; done
    cd cmake

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID-$DISTRO_VERSION_ID" in
        centos-* | fedora-* | rhel-*)
            set +xe
            . scl_source enable devtoolset-9 || exit 1
            set -xe
            export CC="gcc" CXX="g++"
            ;;
        debian-10)
            export CC="gcc-8" CXX="g++-8"
            ;;
        debian-11)
            export CC="gcc-10" CXX="g++-10"
            ;;
        ubuntu-18.* | ubuntu-19.*)
            export CC="gcc-8" CXX="g++-8"
            ;;
        ubuntu-20.* | ubuntu-21.*)
            export CC="gcc-10" CXX="g++-10"
            ;;
        *)
            export CC="gcc" CXX="g++"
            ;;
        esac

        ./bootstrap --prefix="$INSTALL_ABS" --parallel=$(nproc)
        VERBOSE=1 time make -j$(nproc)
        VERBOSE=1 time make -j install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/cmake
)
sudo rm -vf $STAGE/cmake
sync || true
