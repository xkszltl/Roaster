# ================================================================
# Compile OpenBLAS
# ================================================================

[ -e $STAGE/openblas ] && ( set -xe
    cd $SCRATCH

    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/xianyi/OpenBLAS.git; do echo 'Retrying'; done
    cd OpenBLAS
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    . scl_source enable devtoolset-7 || true

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

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

    . "$ROOT_DIR/pkgs/utils/fpm/post_build.sh"

    fpm                                                             \
        --after-install "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"  \
        --after-remove "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"   \
        --chdir "$INSTALL_ROOT"                                     \
        --input-type dir                                            \
        --name "codingcafe-$(basename $(pwd))"                      \
        --output-type rpm                                           \
        --rpm-compression xz                                        \
        --rpm-digest sha512                                         \
        --version "1.66.0"

    . "$ROOT_DIR/pkgs/utils/fpm/install.sh"

    cd
    rm -rf $SCRATCH/OpenBLAS
    wait
)
rm -rvf $STAGE/openblas
sync || true
