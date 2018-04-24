# ================================================================
# Compile Gflags
# ================================================================

[ -e $STAGE/gflags ] && ( set -xe
    cd $SCRATCH
    
    # ------------------------------------------------------------

    until git clone --depth 1 --no-checkout --no-single-branch --recursive $GIT_MIRROR/gflags/gflags.git; do echo 'Retrying'; done
    cd gflags
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

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
