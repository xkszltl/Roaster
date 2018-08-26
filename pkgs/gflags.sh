# ================================================================
# Compile Gflags
# ================================================================

[ -e $STAGE/gflags ] && ( set -xe
    cd $SCRATCH
    
    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" gflags/gflags,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd gflags

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        set -xe

        mkdir -p build
        cd $_

        cmake                                               \
            -DBUILD_PACKAGING=OFF                           \
            -DBUILD_SHARED_LIBS=ON                          \
            -DBUILD_TESTING=ON                              \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo               \
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
    rm -rf $SCRATCH/gflags
)
sudo rm -vf $STAGE/gflags
sync || true
