# ================================================================
# Compile Protobuf
# ================================================================

[ -e $STAGE/protobuf ] && ( set -xe
    cd $SCRATCH

    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/google/protobuf.git; do echo 'Retrying'; done
    cd protobuf
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . scl_source enable devtoolset-7 || true
        set -e
        ./autogen.sh
        ./configure --prefix="$INSTALL_ABS"
        make -j$(nproc)
        make check -j$(nproc)
        make install -j
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
    rm -rf $SCRATCH/protobuf
    wait
)
rm -rvf $STAGE/protobuf
sync || true
