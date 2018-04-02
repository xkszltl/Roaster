# ================================================================
# Compile Protobuf
# ================================================================

[ -e $STAGE/protobuf ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/google/protobuf.git; do echo 'Retrying'; done
    cd protobuf
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +x
        . scl_source enable devtoolset-7 || true
        set -xe
        ./autogen.sh
        ./configure --prefix="$INSTALL_ABS"
        make -j$(nproc)
        make check -j$(nproc)
        make install -j
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/protobuf
)
sudo rm -vf $STAGE/protobuf
sync || true
