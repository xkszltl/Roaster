# ================================================================
# Compile Glog
# ================================================================

[ -e $STAGE/glog ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" google/glog,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd glog
    
    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        set -xe

        mkdir -p build
        cd $_

        cmake                                               \
            -DBUILD_SHARED_LIBS=ON                          \
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
