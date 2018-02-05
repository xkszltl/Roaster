# ================================================================
# Compile Protobuf
# ================================================================

[ -e $STAGE/protobuf ] && ( set -e
    cd $SCRATCH

    until git clone --depth 1 --no-single-branch $GIT_MIRROR/google/protobuf.git; do echo 'Retrying'; done
    cd protobuf
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    . scl_source enable devtoolset-7 || true

    ./autogen.sh
    ./configure --prefix=/usr/local
    make -j$(nproc)
    make check -j$(nproc)
    make install -j

    ldconfig &
    $IS_CONTAINER && ccache -C &
    cd
    rm -rf $SCRATCH/protobuf
    wait
)
rm -rvf $STAGE/protobuf
sync || true
