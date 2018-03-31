# ================================================================
# Compile Jemalloc
# ================================================================

[ -e $STAGE/jemalloc ] && ( set -xe
    cd $SCRATCH
    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/jemalloc/jemalloc.git; do echo 'Retrying'; done
    cd jemalloc
    git checkout $(git tag | sed -n '/^[0-9\.]*$/p' | sort -V | tail -n1)

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . scl_source enable devtoolset-7 || true
        set -e
        ./autogen.sh                    \
            --enable-{prof,xmalloc}     \
            --prefix="$INSTALL_ABS"     \
            --with-jemalloc-prefix=""

        time make -j$(nproc) dist
        time make -j$(nproc)
        time make -j$(nproc) install
    )

    . "$ROOT_DIR/pkgs/utils/fpm/post_build.sh"

    fpm                                                             \
        --after-install "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"  \
        --after-remove "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"   \
        --chdir "$INSTALL_ROOT"                                     \
        --input-type dir                                            \
        --iteration "$(git log -n1 --format="%h")"                  \
        --name "codingcafe-$(basename $(pwd))"                      \
        --output-type rpm                                           \
        --rpm-compression xz                                        \
        --rpm-digest sha512                                         \
        --vendor "CodingCafe"                                       \
        --version "$(git describe --tags)"

    . "$ROOT_DIR/pkgs/utils/fpm/install.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/jemalloc
    wait
)
sudo rm -rvf $STAGE/jemalloc
sync || true
