# ================================================================
# Compile RocksDB
# ================================================================

[ -e $STAGE/rocksdb ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" facebook/rocksdb,v
    until git clone -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd rocksdb

    # ------------------------------------------------------------

    # Patch v6.25 and v6.26 for rados.
    # - https://github.com/facebook/rocksdb/issues/9078
    # - https://github.com/facebook/rocksdb/commit/92e2399669df3fdc6c8573f9a4adf09e50a2796f
    git cherry-pick 92e2399

    # git remote add patch "$GIT_MIRROR_GITHUB/xkszltl/rocksdb.git"
    # git fetch patch
    # for i in; do
    #     git cherry-pick "patch/$i"
    # done

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        # . "/opt/intel/$([ -e '/opt/intel/oneapi/tbb/latest/env/vars.sh' ] && echo 'oneapi/tbb/latest/env/vars.sh' || echo 'tbb/bin/tbbvars.sh')" intel64

        if true; then
            mkdir -p build
            cd $_
            # Known issues:
            #   - The NDEBUG in non-debug cmake build leads to test-related compile error.
            #     Benchmark requires testharness: https://github.com/facebook/rocksdb/issues/6769
            #   - RocksDB enables ccache automatically via RULE_LAUNCH_COMPILE and RULE_LAUNCH_LINK.
            #     https://github.com/facebook/rocksdb/issues/7623
            "$TOOLCHAIN/cmake"                          \
                -DCMAKE_BUILD_TYPE=Release              \
                -DCMAKE_C_COMPILER="$CC"                \
                -DCMAKE_CXX_COMPILER="$CXX"             \
                -DCMAKE_C{,XX}_COMPILER_LAUNCHER=""     \
                -DCMAKE_C{,XX}_FLAGS="-fPIC -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g" \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
                -DCMAKE_VERBOSE_MAKEFILE=ON             \
                -DFAIL_ON_WARNINGS=OFF                  \
                -DFORCE_SSE42=ON                        \
                -DPORTABLE="$($TOOLCHAIN_CPU_NATIVE && echo 'OFF' || echo 'ON')"    \
                -DUSE_RTTI=ON                           \
                -DWITH_ASAN=OFF                         \
                -DWITH_BENCHMARK_TOOLS=OFF              \
                -DWITH_BZ2=ON                           \
                -DWITH_JEMALLOC=OFF                     \
                -DWITH_LIBRADOS=ON                      \
                -DWITH_LZ4=ON                           \
                -DWITH_NUMA=ON                          \
                -DWITH_SNAPPY=ON                        \
                -DWITH_TBB=OFF                          \
                -DWITH_TESTS=OFF                        \
                -DWITH_TSAN=OFF                         \
                -DWITH_UBSAN=OFF                        \
                -DWITH_ZLIB=ON                          \
                -DWITH_ZSTD=ON                          \
                -G"Ninja"                               \
                ..
            time "$TOOLCHAIN/cmake" --build .
            # time "$TOOLCHAIN/cmake" --build . --target check
            time "$TOOLCHAIN/cmake" --build . --target install
        else
            . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
            export CC="$TOOLCHAIN/$CC"
            export CXX="$TOOLCHAIN/$CXX"
            export LD="$TOOLCHAIN/ld"
            $TOOLCHAIN_CPU_NATIVE || export PORTABLE=1
            export USE_SSE=1
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
