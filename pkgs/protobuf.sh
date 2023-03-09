# ================================================================
# Compile Protobuf
# ================================================================

[ -e $STAGE/protobuf ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" benjaminp/six

    # ------------------------------------------------------------

    # Known issues:
    # - Protobuf 3.21 is re-versioned as 4.21 in Python with breaking changes.
    . "$ROOT_DIR/pkgs/utils/git/version.sh" protocolbuffers/protobuf,v3.20.
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd protobuf

    PATCHES=""
    git remote add patch "$GIT_MIRROR/xkszltl/protobuf.git"
    for i in $PATCHES; do
        git fetch patch
        git cherry-pick "patch/$i"
    done

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        if false; then
            export CC="ccache $CC"
            export CXX="ccache $CXX"
            export C{,XX}FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -fPIC -O3 -g -DDPYTHON_PROTO2_CPP_IMPL_V2"

            ./autogen.sh
            ./configure --prefix="$INSTALL_ABS"
            make -j$(nproc)
            make check -j$(nproc)
            make install -j
        else
            mkdir -p build
            cd $_

            "$TOOLCHAIN/cmake"                          \
                -DBUILD_SHARED_LIBS=ON                  \
                -DCMAKE_BUILD_TYPE=Release              \
                -DCMAKE_C_COMPILER="$CC"                \
                -DCMAKE_CXX_COMPILER="$CXX"             \
                -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
                -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g -DPYTHON_PROTO2_CPP_IMPL_V2"   \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
                -Dprotobuf_BUILD_EXAMPLES=ON            \
                -Dprotobuf_INSTALL_EXAMPLES=ON          \
                -G"Ninja"                               \
                ../cmake

            time "$TOOLCHAIN/cmake" --build .
            time "$TOOLCHAIN/cmake" --build . --target check
            time "$TOOLCHAIN/cmake" --build . --target install
        fi
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # Fake makefile output for CMake build due to hard-coded path in "setup.py".
    [ ! -d 'build' ] || ln -sf '../build' 'src/.libs'

    # Known issues:
    # - Protobuf 3.20 drops Python 3.6 support.
    #   https://github.com/protocolbuffers/protobuf/pull/9480
    #   https://github.com/protocolbuffers/protobuf/commit/301d315dc4674d1bc799446644e88eff0af1ac86
    # - Protobuf 3.21 is re-versioned as 4.21 in Python with breaking changes.
    PROTOC="$(realpath -e 'build/protoc')" "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" \
        protocolbuffers/protobuf/./python,v3.20.[3.6=v3.19.]

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/protobuf
)
sudo rm -vf $STAGE/protobuf
sync "$STAGE" || true
