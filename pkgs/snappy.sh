# ================================================================
# Compile Snappy
# ================================================================

[ -e $STAGE/snappy ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" google/snappy,
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd snappy

    # Patch build error in 1.1.9 and master above it.
    # - https://github.com/google/snappy/pull/128
    git grep --name-only 'AdvanceToNextTag' | xargs -rn1 sed -i 's/^\([[:space:]]*\)\(size_t AdvanceToNextTag[[:alnum:]_]*(\)/\1inline \2/'
    git diff --exit-code || git commit -am 'Patch for missing-inline erorr in AdvanceToNextTag().'

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-9 || exit 1
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
        "$TOOLCHAIN/cmake"                          \
            -DBENCHMARK_ENABLE_INSTALL=OFF          \
            -DBUILD_SHARED_LIBS=ON                  \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DINSTALL_GTEST=OFF                     \
            -DSNAPPY_BUILD_TESTS=OFF                \
            -DSNAPPY_REQUIRE_AVX2=ON                \
            -G"Ninja"                               \
            ..

        time "$TOOLCHAIN/cmake" --build .
        # time "$TOOLCHAIN/ctest" --output-on-failure -j"$(nproc)"
        time "$TOOLCHAIN/cmake" --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/snappy
)
sudo rm -vf $STAGE/snappy
sync || true
