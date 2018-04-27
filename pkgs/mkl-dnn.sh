# ================================================================
# Compile Intel MKL-DNN
# ================================================================

[ -e $STAGE/mkl-dnn ] && ( set -xe
    cd $SCRATCH

    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/intel/mkl-dnn.git; do echo 'Retrying'; done
    cd mkl-dnn
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)
    
    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        . "/opt/intel/compilers_and_libraries/$(uname -s | tr '[A-Z]' '[a-z]')/mkl/bin/mklvars.sh" intel64
        set -xe

        mkdir -p build
        cd $_

        cmake                                               \
            -DCMAKE_BUILD_TYPE=Release                      \
            -DCMAKE_C_COMPILER_LAUNCHER=ccache              \
            -DCMAKE_C{,XX}_FLAGS="-g"                       \
            -DCMAKE_CXX_COMPILER_LAUNCHER=ccache            \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
            -G"Ninja"                                       \
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
