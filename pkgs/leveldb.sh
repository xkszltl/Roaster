# ================================================================
# Compile LevelDB
# ================================================================

[ -e $STAGE/leveldb ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" google/leveldb,
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd leveldb

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        # CMake script it not ready for dynamic lib.
        if [ -e CMakeLists.txt ]; then
            mkdir -p build
            cd $_

            # Use -fPIC since cmake script only creates static lib.
            "$TOOLCHAIN/cmake"                          \
                -DCMAKE_BUILD_TYPE=Release              \
                -DCMAKE_C_COMPILER="$CC"                    \
                -DCMAKE_CXX_COMPILER="$CXX"                 \
                -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
                -DCMAKE_C{,XX}_FLAGS="-fPIC -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g" \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
                -G"Ninja"                               \
                ..

            time "$TOOLCHAIN/cmake" --build .
            # Parallel test not fully supported.
            time "$TOOLCHAIN/ctest" --output-on-failure
            time "$TOOLCHAIN/cmake" --build . --target install
            ./db_bench
        else
            make -j$(nproc)
            make check -j$(nproc)

            mkdir -p "$INSTALL_ABS/include/leveldb/"
            install include/leveldb/*.h $_
            mkdir -p "$INSTALL_ABS/lib"
            install out-*/lib*.* $_

            # Replace duplicated lib with symlink
            pushd $_
            for i in $(ls lib*.so.*); do
                ln -sf "$i" "$(sed 's/\.[^\.]*$//' <<<"$i")"
            done
            popd
        fi

        # Exclude GTest files.
        pushd "$INSTALL_ROOT"
        for i in benchmark gtest; do
            case "$DISTRO_ID" in
            'centos' | 'fedora' | 'rhel' | 'scientific')
                [ "$(rpm -qa "roaster-$i")" ] || continue
                rpm -ql "roaster-$i" | sed -n 's/^\//\.\//p' | xargs rm -rf
                ;;
            'debian' | 'linuxmint' | 'ubuntu')
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
    rm -rf $SCRATCH/leveldb
)
sudo rm -vf $STAGE/leveldb
sync || true
