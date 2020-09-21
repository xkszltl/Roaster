# ================================================================
# Compile Tencent RapidJson
# ================================================================

[ -e $STAGE/rapidjson ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" Tencent/rapidjson,master
    until git clone --depth 1 --recursive --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd rapidjson

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

        cmake                                           \
            -DCMAKE_BUILD_TYPE=Release                  \
            -DCMAKE_C_COMPILER="$CC"                    \
            -DCMAKE_CXX_COMPILER="$CXX"                 \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache     \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"       \
            -DRAPIDJSON_BUILD_THIRDPARTY_GTEST=OFF      \
            -DRAPIDJSON_HAS_STDSTRING=ON                \
            -DGTEST_SEARCH_PATH='/usr/local/src/gtest'  \
            -G"Ninja"                                   \
            ..

        time cmake --build .
        # Valgrind unit test may fail: https://github.com/Tencent/rapidjson/issues/1520
        time cmake --build . --target test || true
        time cmake --build . --target install

        # Exclude GTest files.
        pushd "$INSTALL_ROOT"
        for i in gtest; do
            case "$DISTRO_ID" in
            'centos' | 'fedora' | 'rhel')
                [ "$(rpm -qa "roaster-$i")" ] || continue
                rpm -ql "roaster-$i" | sed -n 's/^\//\.\//p' | xargs rm -rf
                ;;
            'ubuntu')
                dpkg -l "roaster-$i" && dpkg -L "roaster-$i" | xargs -n1 | xargs -i -n1 find {} -maxdepth 0 -not -type d | sed -n 's/^\//\.\//p' | xargs rm -rf
                ;;
            esac
        done
        rm -rf ./usr/local/lib*/libgtest*
        rm -rf ./usr/local/include/gtest
        popd
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/rapidjson
)
sudo rm -vf $STAGE/rapidjson
sync || true
