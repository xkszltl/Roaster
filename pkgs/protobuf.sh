# ================================================================
# Compile Protobuf
# ================================================================

[ -e $STAGE/protobuf ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    until git clone --depth 1 --single-branch -b "$(git ls-remote --tags "$GIT_MIRROR/google/protobuf.git" | sed -n 's/.*[[:space:]]refs\/tags\/\(v[0-9\.]*\)/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/google/protobuf.git"; do echo 'Retrying'; done
    cd protobuf
    until git clone --depth 1 --single-branch --recursive -b "$(git ls-remote --tags "$GIT_MIRROR/google/googletest.git" | sed -n 's/.*[[:space:]]refs\/tags\/\(release-[0-9\.]*\)$/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/google/googletest.git"; do echo 'Retrying'; done
    rm -rf gmock
    mkdir -p $_
    pushd $_
    ln -sf ../googletest/googlemock/* .
    ln -sf ../googletest/googletest gtest
    popd

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +x
        . scl_source enable devtoolset-7 || true
        set -xe
        # ./autogen.sh
        # ./configure --prefix="$INSTALL_ABS"
        # make -j$(nproc)
        # make check -j$(nproc)
        # make install -j

        mkdir -p build
        cd $_

        cmake                                       \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER_LAUNCHER=ccache      \
            -DCMAKE_C{,XX}_FLAGS="-g"               \
            -DCMAKE_CXX_COMPILER_LAUNCHER=ccache    \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -Dprotobuf_BUILD_EXAMPLES=ON            \
            -Dprotobuf_BUILD_SHARED_LIBS=ON         \
            -Dprotobuf_INSTALL_EXAMPLES=ON          \
            -G"Ninja"                               \
            ../cmake

        time cmake --build .
        time cmake --build . --target check
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/protobuf
)
sudo rm -vf $STAGE/protobuf
sync || true
