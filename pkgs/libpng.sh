# ================================================================
# Compile Libpng
# ================================================================

[ -e $STAGE/libpng ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    export _GIT_MIRROR="$GIT_MIRROR"
    export GIT_MIRROR="$GIT_MIRROR_CODINGCAFE"
    . "$ROOT_DIR/pkgs/utils/git/version.sh" libpng/libpng,v
    export GIT_MIRROR="$_GIT_MIRROR"
    env -u _GIT_MIRROR

    if [ "_$GIT_MIRROR" == "_$GIT_MIRROR_CODINGCAFE" ]; then
        until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    else
        until git clone --single-branch -b "$GIT_TAG" "git://git.code.sf.net/p/libpng/code" libpng; do echo 'Retrying'; done
    fi
    cd libpng

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        # . scl_source enable devtoolset-8
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        cmake                                               \
            -DCMAKE_BUILD_TYPE=Release                      \
            -DCMAKE_C_COMPILER=gcc                          \
            -DCMAKE_CXX_COMPILER=g++                        \
            -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache   \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
            -DCMAKE_VERBOSE_MAKEFILE=ON                     \
            -G"Ninja"                                       \
            ..

        time cmake --build . --target
        time cmake --build . --target install
        time cmake --build . --target test
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"
    
    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/libpng
)
sudo rm -vf $STAGE/libpng
sync || true
