# ================================================================
# Compile Intel MKL-DNN
# ================================================================

[ -e $STAGE/mkl-dnn ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" intel/mkl-dnn,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd mkl-dnn
    
    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        . "/opt/intel/compilers_and_libraries/$(uname -s | tr '[A-Z]' '[a-z]')/mkl/bin/mklvars.sh" intel64
        set -xe

        mkdir -p build
        cd $_

        cmake                                       \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-g"               \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -G"Ninja"                               \
            ..

        time cmake --build .
        time cmake --build . --target test
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/mkl-dnn
)
sudo rm -vf $STAGE/mkl-dnn
sync || true
