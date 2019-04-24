# ================================================================
# Compile RocksDB
# ================================================================

[ -e $STAGE/rocksdb ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" Maratyszcza/{confu,PeachPy},master

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" facebook/rocksdb,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd rocksdb

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-8
            set -xe
            ;;
        'ubuntu')
            export CC="$(which gcc-8)" CXX="$(which g++-8)"
            ;;
        esac

        # . /opt/intel/tbb/bin/tbbvars.sh intel64

        if false; then
            mkdir -p build
            cd $_
            # The NDEBUG in non-debug cmake build leads to test-related compile error.
            cmake                                       \
                -DCMAKE_BUILD_TYPE=RelWithDebInfo       \
                -DCMAKE_C{,XX}_FLAGS="-O3 -g"           \
                -DCMAKE_C{,XX}_FLAGS_RELWITHDEBINFO=""  \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
                -DCMAKE_VERBOSE_MAKEFILE=ON             \
                -FAIL_ON_WARNINGS=OFF                   \
                -DUSE_RTTI=1                            \
                -DWITH_BZ2=ON                           \
                -DWITH_JEMALLOC=OFF                     \
                -DWITH_LIBRADOS=ON                      \
                -DWITH_LZ4=ON                           \
                -DWITH_SNAPPY=ON                        \
                -DWITH_TBB=OFF                          \
                -DWITH_ZLIB=ON                          \
                -DWITH_ZSTD=ON                          \
                -G"Ninja"                               \
                ..
            time cmake --build .
            time cmake --build . --target check
            time cmake --build . --target install
        else
            . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
            export CC="$TOOLCHAIN/cc"
            export CXX="$TOOLCHAIN/c++"
            export LD="$TOOLCHAIN/ld"
            time make DEBUG_LEVEL=0 -j$(nproc) {static,shared}_lib
            # time make -j$(nproc) package
            # time make -j$(nproc) check
            time make DEBUG_LEVEL=0 INSTALL_PATH="$INSTALL_ABS" -j install{,-shared}
        fi
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/rocksdb
)
sudo rm -vf $STAGE/rocksdb
sync || true
