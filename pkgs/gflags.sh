# ================================================================
# Compile Gflags
# ================================================================

[ -e $STAGE/gflags ] && ( set -xe
    cd $SCRATCH

    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/gflags/gflags.git; do echo 'Retrying'; done
    cd gflags
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +x

        # . scl_source enable devtoolset-7 || true

        # Downgrade to gcc-5 to solve "unrecognized relocation" error in caffe2.
        . scl_source enable devtoolset-4 || true

        set -xe

        mkdir -p build
        cd $_

        cmake                                               \
            -G"Ninja"                                       \
            -DBUILD_PACKAGING=OFF                           \
            -DBUILD_SHARED_LIBS=ON                          \
            -DBUILD_TESTING=ON                              \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo               \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
            ..

        time cmake --build .
        time cmake --build . --target test
        time cmake --build . --target install
    )

    . "$ROOT_DIR/pkgs/utils/fpm/post_build.sh"

    fpm                                                             \
        --after-install "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"  \
        --after-remove "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"   \
        --chdir "$INSTALL_ROOT"                                     \
        --exclude-file "$INSTALL_ROOT/../exclude.conf"              \
        --input-type dir                                            \
        --iteration "$(git log -n1 --format="%h")"                  \
        --name "codingcafe-$(basename $(pwd))"                      \
        --output-type rpm                                           \
        --package "$INSTALL_ROOT/.."                                \
        --rpm-compression xz                                        \
        --rpm-digest sha512                                         \
        --vendor "CodingCafe"                                       \
        --version "$(git describe --tags | sed 's/[^0-9\.]//g')"

    "$ROOT_DIR/pkgs/utils/fpm/install.sh"

    cd
    rm -rf $SCRATCH/gflags
    wait
)
sudo rm -vf $STAGE/gflags
sync || true
