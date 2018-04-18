# ================================================================
# Compile LevelDB
# ================================================================

[ -e $STAGE/leveldb ] && ( set -xe
    cd $SCRATCH
    
    # ------------------------------------------------------------

    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/google/leveldb.git; do echo 'Retrying'; done
    cd leveldb
    # git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)
    git checkout master
    git tag "$(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1).1"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +x
        . scl_source enable devtoolset-7 || true
        set -xe

        if [ -e CMakeLists.txt ]; then
            mkdir -p build
            cd $_

            cmake                                       \
                -DCMAKE_BUILD_TYPE=Release              \
                -DCMAKE_C_COMPILER_LAUNCHER=ccache      \
                -DCMAKE_C{,XX}_FLAGS="-g"               \
                -DCMAKE_CXX_COMPILER_LAUNCHER=ccache    \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
                -G"Ninja"                               \
                ..

            time cmake --build .
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
