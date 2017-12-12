# ================================================================
# Compile Jemalloc
# ================================================================

[ -e $STAGE/jemalloc ] && ( set -e
    cd $SCRATCH
    until git clone $GIT_MIRROR/jemalloc/jemalloc.git; do echo 'Retrying'; done
    cd jemalloc
    git checkout $(git tag | sed -n '/^[0-9\.]*$/p' | sort -V | tail -n1)

    # ------------------------------------------------------------

    . scl_source enable devtoolset-7

    ./autogen.sh                    \
        --enable-{prof,xmalloc}     \
        --prefix="/usr/local/"      \
        --with-jemalloc-prefix=""

    time make -j$(nproc) dist
    time make -j$(nproc)
    time make -j$(nproc) install

    # ------------------------------------------------------------

    echo '/usr/local/lib' > /etc/ld.so.conf.d/jemalloc.conf
    ldconfig &
    ccache -C &
    cd
    rm -rf $SCRATCH/jemalloc
    wait
) && rm -rvf $STAGE/jemalloc
sync || true
