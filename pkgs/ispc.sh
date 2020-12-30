# ================================================================
# Compile ISPC
# ================================================================

[ -e $STAGE/ispc ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" ispc/ispc,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd ispc

    sed -i "s/$(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR_GITHUB")\(\/..*\/.*\.git\)/$(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR")\1/" CMakeLists.txt

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        "$TOOLCHAIN/cmake"                                      \
            -DCMAKE_BUILD_TYPE=Release                          \
            -DCMAKE_C_COMPILER="clang"                          \
            -DCMAKE_CXX_COMPILER="clang++"                      \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache             \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_{EXE,SHARED}_LINKER_FLAGS="-fuse-ld=lld"    \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"               \
            -DISPC_INCLUDE_BENCHMARKS=ON                        \
            -DISPC_INCLUDE_RT=OFF                               \
            -DISPC_PREPARE_PACKAGE=OFF                          \
            -G"Ninja"                                           \
            ..

        time "$TOOLCHAIN/cmake" --build .
        time "$TOOLCHAIN/cmake" --build . --target check-all
        time "$TOOLCHAIN/ctest" --output-on-failure -j"$(nproc)"
        time "$TOOLCHAIN/cmake" --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/ispc
)
sudo rm -vf $STAGE/ispc
sync || true
