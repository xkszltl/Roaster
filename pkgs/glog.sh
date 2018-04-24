# ================================================================
# Compile Glog
# ================================================================

[ -e $STAGE/glog ] && ( set -xe
    cd $SCRATCH

    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/google/glog.git; do echo 'Retrying'; done
    cd glog
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)
    
    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        # . scl_source enable devtoolset-7
        # Downgrade to gcc-5 to solve "unrecognized relocation" error in caffe2.
        . scl_source enable devtoolset-4
        set -xe

        mkdir -p build
        cd $_

        cmake                                               \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo               \
            -DCMAKE_C_COMPILER=gcc                          \
            -DCMAKE_CXX_COMPILER=g++                        \
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
    rm -rf $SCRATCH/glog
)
sudo rm -vf $STAGE/glog
sync || true
