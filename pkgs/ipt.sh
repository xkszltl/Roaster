# ================================================================
# Compile Intel Processor Trace decoder library
# ================================================================

[ -e $STAGE/ipt ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" 01org/processor-trace,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO" ipt; do echo 'Retrying'; done
    cd ipt

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-9
            set -xe
            export CC="gcc" CXX="g++"
            ;;
        'ubuntu')
            export CC="gcc-8" CXX="g++-8"
            ;;
        esac

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        # TODO: Enable test once the gtest linking issue is fixed (already in PR)
        cmake                                       \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DSIDEBAND=ON                           \
            -DFEATURE_ELF=ON                        \
            -DMAN=ON                                \
            -DPEVENT=ON                             \
            -DPTDUMP=ON                             \
            -DPTTC=ON                               \
            -DPTUNIT=ON                             \
            -DPTXED=OFF                             \
            -G"Ninja"                               \
            ..

        time cmake --build .
        CTEST_PARALLEL_LEVEL="$(nproc)" time cmake --build . --target test
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/ipt
)
sudo rm -vf $STAGE/ipt
sync || true
