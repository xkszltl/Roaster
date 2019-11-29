# ================================================================
# Compile LevelDB
# ================================================================

[ -e $STAGE/leveldb ] && ( set -xe
    cd $SCRATCH
    
    # ------------------------------------------------------------

    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/google/leveldb.git; do echo 'Retrying'; done
    cd leveldb
    # No new release for years.
    git checkout master

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    git tag "$(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1).1"

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

        # CMake script it not ready for dynamic lib.
        if [ -e CMakeLists.txt ]; then
            mkdir -p build
            cd $_

            # Use -fPIC since cmake script only creates static lib.
            cmake                                       \
                -DCMAKE_BUILD_TYPE=Release              \
                -DCMAKE_C_COMPILER="$CC"                    \
                -DCMAKE_CXX_COMPILER="$CXX"                 \
                -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
                -DCMAKE_C{,XX}_FLAGS="-fPIC -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g" \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
                -G"Ninja"                               \
                ..

            time cmake --build .
            # Parallel test not fully supported.
            time cmake --build . --target test
            time cmake --build . --target install
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

    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/leveldb
)
sudo rm -vf $STAGE/leveldb
sync || true
