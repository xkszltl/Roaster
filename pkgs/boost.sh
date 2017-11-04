# ================================================================
# Compile Boost
# ================================================================

[ -e $STAGE/boost ] && ( set -e
    cd $SCRATCH

    if [ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ]; then
        export HTTP_PROXY=proxy.codingcafe.org:8118
        [ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
        [ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
        [ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY
    fi

    mkdir -p boost
    cd $_
    curl -sSL https://dl.bintray.com/boostorg/release/1.65.1/source/boost_1_65_1.tar.bz2 | tar -jxvf - --strip-components=1

    . scl_source enable devtoolset-7
    ./bootstrap.sh
    ./b2 -aj`nproc` install

    # ------------------------------------------------------------

    ldconfig &
    ccache -C &
    cd
    rm -rf $SCRATCH/boost
    wait
) && rm -rvf $STAGE/boost
sync || true
