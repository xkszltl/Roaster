# ================================================================
# Compile Boost
# ================================================================

[ -e $STAGE/boost ] && ( set -xe
    cd $SCRATCH

    if [ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ]; then
        # export HTTP_PROXY=proxy.codingcafe.org:8118
        [ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
        [ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
        [ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY
    fi

    mkdir -p boost
    cd $_
    curl -sSL https://dl.bintray.com/boostorg/release/1.66.0/source/boost_1_66_0.tar.bz2 | tar -jxvf - --strip-components=1

    . scl_source enable devtoolset-7 || true

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    ./bootstrap.sh --prefix="$INSTALL_ABS"
    ./b2 -aj$(nproc) install

    . "$ROOT_DIR/pkgs/utils/fpm/post_build.sh"

    fpm                                                             \
        --after-install "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"  \
        --after-remove "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"   \
        --chdir "$INSTALL_ABS"                                      \
        --input-type dir                                            \
        --name "codingcafe-$(basename $(pwd))"                      \
        --output-type rpm                                           \
        --rpm-compression xz                                        \
        --rpm-digest sha512                                         \
        --version "1.66.0"

    . "$ROOT_DIR/pkgs/utils/fpm/install.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/boost
    wait
)
rm -rvf $STAGE/boost
sync || true
