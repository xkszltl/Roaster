# ================================================================
# Compile GTest/GMock
# ================================================================

[ -e $STAGE/gtest ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    until git clone --depth 1 --single-branch -b "$(git ls-remote --tags "$GIT_MIRROR/google/googletest.git" | sed -n 's/.*[[:space:]]refs\/tags\/\(release-[0-9\.]*\)[[:space:]]*$/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/google/googletest.git" gtest; do echo 'Retrying'; done
    # until git clone --depth 1 --single-branch "$GIT_MIRROR/google/googletest.git" gtest; do echo 'Retrying'; done
    cd gtest
    # git tag "$(git ls-remote --tags "$GIT_MIRROR/google/googletest.git" | sed -n 's/.*[[:space:]]refs\/tags\/\(release-[0-9\.]*\)[[:space:]]*$/\1/p' | sort -V | tail -n1).1"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +x
        . scl_source enable devtoolset-7 || true
        set -xe

        mkdir -p build
        cd $_

        cmake                                       \
            -DBUILD_GMOCK=ON                        \
            -DBUILD_GTEST=ON                        \
            -DBUILD_SHARED_LIBS=ON                  \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER_LAUNCHER=ccache      \
            -DCMAKE_C{,XX}_FLAGS="-g"               \
            -DCMAKE_CXX_COMPILER_LAUNCHER=ccache    \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -Dgmock_build_tests=ON                  \
            -Dgtest_build_samples=ON                \
            -Dgtest_build_tests=ON                  \
            -G"Ninja"                               \
            ..

        time cmake --build .
        time cmake --build . --target test || true
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/gtest
)
sudo rm -vf $STAGE/gtest
sync || true
