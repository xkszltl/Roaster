# ================================================================
# Compile Boost
# ================================================================

[ -e $STAGE/boost ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------
    # Download source code
    # ------------------------------------------------------------

    if [ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ]; then
        # export HTTP_PROXY=proxy.codingcafe.org:8118
        [ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
        [ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
        [ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY
    fi

    mkdir -p boost
    cd $_
    curl -sSL https://dl.bintray.com/boostorg/release/1.66.0/source/boost_1_66_0.tar.bz2 | tar -jxvf - --strip-components=1

    # ------------------------------------------------------------
    # Create local git repo for installation script
    # ------------------------------------------------------------

    git init
    git add -A
    git commit                                              \
        --author='CodingCafe Build <build@codigcafe.org>'   \
        --message='CodingCafe'
    git tag '1.66.0'

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +x
        . scl_source enable devtoolset-7 || true
        set -xe
        ./bootstrap.sh --prefix="$INSTALL_ABS"
        ./b2 -aj$(nproc) install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/boost
)
sudo rm -vf $STAGE/boost
sync || true
