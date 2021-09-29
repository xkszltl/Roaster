# ================================================================
# Compile SIMDJson
# ================================================================

[ -e $STAGE/simdjson ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" simdjson/simdjson,v
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd simdjson

    if [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ] && grep '^https://' <<< "$GIT_MIRROR_CODINGCAFE" >/dev/null; then
        sed -i 's/"'"$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< 'https://github.com/${GITHUB_REPO}/archive/${COMMIT}.zip')"'"/"'"$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$GIT_MIRROR_CODINGCAFE"'/${GITHUB_REPO}/-/archive/${COMMIT}.zip')"'"/' dependencies/import.cmake
        ! git diff --exit-code || git commit -am 'Work around github connection requirements.'
    fi

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        mkdir -p build
        cd $_

        "$TOOLCHAIN/cmake"                          \
            -DBUILD_SHARED_LIBS=ON                  \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DSIMDJSON_COMPETITION=OFF              \
            -GNinja                                 \
            ..

        time "$TOOLCHAIN/cmake" --build .
        # Known issues:
        #   - checkperf test may fail when running under load.
        time "$TOOLCHAIN/ctest" --output-on-failure -j"$(nproc)" || time "$TOOLCHAIN/ctest" --output-on-failure || true
        time "$TOOLCHAIN/cmake" --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/simdjson
)
sudo rm -vf $STAGE/simdjson
sync || true
