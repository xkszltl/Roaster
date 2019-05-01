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
    MAX_FALLBACK=3
    for i in $(seq "$MAX_FALLBACK"); do
        export BOOST_VERSION="$(
            curl -sSL $BOOST_SITE                                                   \
            | sed -n 's/.*href[[:space:]]*=[[:space:]]*"\([0-9\.]*\)\/*".*/\1/p'    \
            | sort -V                                                               \
            | tail -n "$i"                                                          \
            | head -n1
        )"
        [ "$BOOST_VERSION" ] || continue
        BOOST_URL="$BOOST_SITE/$BOOST_VERSION/source/boost_$(sed 's/[^0-9]/_/g' <<<"$BOOST_VERSION").tar.bz2"
        curl -fsSIL "$BOOST_URL" && break
    done
    [ "$BOOST_URL" ]

    mkdir -p boost
    cd $_
    curl -sSL "$BOOST_URL" | tar -jxvf - --strip-components=1

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
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-8
            set -xe
            export CC="gcc" CXX="g++"
            ;;
        'ubuntu')
            export CC="gcc-8" CXX="g++-8"
            ;;
        esac

        ./bootstrap.sh --prefix="$INSTALL_ABS"
        ./b2 -aj$(nproc) install numa=on

        # Boost 1.67.0 cannot find the correct include path with suffix ("python3.6m")
        ./bootstrap.sh --prefix="$INSTALL_ABS" --with-python=python3
        ./b2 -aj$(nproc) install include="$(python3 -c 'import distutils.sysconfig as c; print(c.get_python_inc())')" numa=on
    )

    # Temporary patch util cmake can detect Boost.Python with suffix.
    pushd "$INSTALL_ABS/lib"
    for i in $(ls libboost_python3?.*); do
        ln -sf "$i" "$(sed 's/^\([^\.0-9]*\)[0-9]*/\1/' <<< "$i")"
    done
    popd

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/boost
)
sudo rm -vf $STAGE/boost
sync || true
