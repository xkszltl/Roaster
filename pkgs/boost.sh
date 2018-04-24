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

    export BOOST_SITE='https://dl.bintray.com/boostorg/release'
    export BOOST_VERSION="$(
        curl -sSL $BOOST_SITE                                                   \
        | sed -n 's/.*href[[:space:]]*=[[:space:]]*"\([0-9\.]*\)\/*".*/\1/p'    \
        | sort -V                                                               \
        | tail -n1
    )"
    [ "$BOOST_VERSION" ]

    mkdir -p boost
    cd $_
    curl -sSL "$BOOST_SITE/$BOOST_VERSION/source/boost_$(sed 's/[^0-9]/_/g' <<<"$BOOST_VERSION").tar.bz2" | tar -jxvf - --strip-components=1

    # ------------------------------------------------------------
    # Create local git repo for installation script
    # ------------------------------------------------------------

    git init
    git add -A
    git commit                                              \
        --author='CodingCafe Build <build@codigcafe.org>'   \
        --message='CodingCafe'                              \
        --quiet
    git tag "$BOOST_VERSION"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
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
