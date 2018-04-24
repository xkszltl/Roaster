# ================================================================
# Compile Eigen
# ================================================================

[ -e $STAGE/eigen ] && ( set -xe
    cd $SCRATCH

    # until git clone --depth 1 --single-branch -b "$(git ls-remote --tags "$GIT_MIRROR/eigenteam/eigen-git-mirror.git" | sed -n 's/.*[[:space:]]refs\/tags\/\([0-9\.]*\)[[:space:]]*$/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/eigenteam/eigen-git-mirror.git" "eigen"; do echo 'Retrying'; done
    # Release 3.3.4 is not compatible with CUDA 9.1.
    until git clone --depth 1 --single-branch -b "master" "$GIT_MIRROR/eigenteam/eigen-git-mirror.git" "eigen"; do echo 'Retrying'; done
    cd eigen
    git tag "$(git ls-remote --tags "$GIT_MIRROR/eigenteam/eigen-git-mirror.git" | sed -n 's/.*[[:space:]]refs\/tags\/\([0-9\.]*\)[[:space:]]*$/\1/p' | sort -V | tail -n1).1"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        set -xe

        mkdir -p build
        cd $_

        cmake                                       \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER_LAUNCHER=ccache      \
            -DCMAKE_C{,XX}_FLAGS="-g"               \
            -DCMAKE_CXX_COMPILER_LAUNCHER=ccache    \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DEIGEN_TEST_CUDA=ON                    \
            -DEIGEN_TEST_CXX11=ON                   \
            -G"Ninja"                               \
            ..

        time cmake --build . --target blas
        # Check may take hours.
        # time cmake --build . --target check
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/eigen
)
sudo rm -vf $STAGE/eigen
sync || true
