# ================================================================
# Compile OpenBLAS
# ================================================================

[ -e $STAGE/openblas ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/xianyi/OpenBLAS.git; do echo 'Retrying'; done
    cd OpenBLAS
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        set -xe

        # mkdir -p build
        # pushd $_

        # cmake                                     \
        #     -DCMAKE_BUILD_TYPE=Release            \
        #     -DCMAKE_C_COMPILER=gcc                \
        #     -DCMAKE_CXX_COMPILER=g++              \
        #     -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS" \
        #     -DCMAKE_VERBOSE_MAKEFILE=ON           \
        #     ..

        # time cmake --build . -- -j$(nproc)
        # time cmake --build . --target test
        # time cmake --build . --target install

        # popd

        make PREFIX="$INSTALL_ABS" -j$(nproc)
        make PREFIX="$INSTALL_ABS" lapack-test -j$(nproc)
        make PREFIX="$INSTALL_ABS" blas-test -j$(nproc)
        make PREFIX="$INSTALL_ABS" install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"
    
    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/OpenBLAS
)
sudo rm -vf $STAGE/openblas
sync || true
