# ================================================================
# Compile SIMDJson
# ================================================================

[ -e $STAGE/simdjson ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" simdjson/simdjson,v
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd simdjson

    # Patch for https://github.com/simdjson/simdjson/issues/977
    git fetch origin master
    git merge 4ec5648

    if [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ] && grep '^https://' <<< "$GIT_MIRROR_CODINGCAFE" >/dev/null; then
        sed -i 's/"'"$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< 'https://github.com/${GITHUB_REPO}/archive/${COMMIT}.zip')"'"/"'"$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$GIT_MIRROR_CODINGCAFE"'/${GITHUB_REPO}/-/archive/${COMMIT}.zip')"'"/' dependencies/import.cmake
        ! git diff --exit-code --name-only || git commit -am 'Work around github connection requirements.'
    fi

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-9 rh-git218 || exit 1
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
