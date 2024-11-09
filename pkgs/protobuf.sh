# ================================================================
# Compile Protobuf
# ================================================================

[ -e $STAGE/protobuf ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" benjaminp/six

    # ------------------------------------------------------------

    # Known issues:
    # - Protobuf 3.21 is re-versioned as 4.21 in Python with breaking changes.
    # - Protobuf has tags without major version like v28.3 for v5.28.3.
    #   Pin major version to 5 until we have more clarity on their versioning scheme.
    . "$ROOT_DIR/pkgs/utils/git/version.sh" protocolbuffers/protobuf,v5.
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
        set -e

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

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
            -Dprotobuf_BUILD_CONFORMANCE=ON         \
            -Dprotobuf_BUILD_EXAMPLES=ON            \
            -Dprotobuf_BUILD_LIBPROTOC=ON           \
            -Dprotobuf_BUILD_LIBUPB=ON              \
            -Dprotobuf_INSTALL_EXAMPLES=ON          \
            -Dprotobuf_USE_EXTERNAL_GTEST=ON        \
            -G"Ninja"                               \
            ..

        time "$TOOLCHAIN/cmake" --build .
        time "$TOOLCHAIN/ctest" --output-on-failure -j"$(nproc)"
        time "$TOOLCHAIN/cmake" --build . --target install
    )

    # Protobuf 3.22 introduces jsoncpp dependency.
    # - https://github.com/protocolbuffers/protobuf/pull/10739
    # - https://github.com/protocolbuffers/protobuf/commit/5308cf0aa67881ff0fc5518e02144e93bc342e83
    # Exclude jsoncpp files.
    pushd "$INSTALL_ROOT"
    for i in jsoncpp; do
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel' | 'scientific')
            [ "$(rpm -qa "roaster-$i")" ] || continue
            rpm -ql "roaster-$i" | sed -n 's/^\//\.\//p' | xargs rm -rf
            ;;
        'debian' | 'linuxmint' | 'ubuntu')
            dpkg -l "roaster-$i" && dpkg -L "roaster-$i" | xargs -n1 | xargs -i -n1 find {} -maxdepth 0 -not -type d | sed -n 's/^\//\.\//p' | xargs rm -rf
            ;;
        esac
    done
    popd

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # Known issues:
    # - Protobuf 3.20 drops Python 3.6 support.
    #   https://github.com/protocolbuffers/protobuf/pull/9480
    #   https://github.com/protocolbuffers/protobuf/commit/301d315dc4674d1bc799446644e88eff0af1ac86
    # - Python Protobuf 4.25 drops Python 3.7 support.
    # - Protobuf 3.21 is re-versioned as 4.21 in Python with breaking changes.
    # - Python Protobuf 5.26 removes setup.py and only supports bazel for wheel build.
    #   https://github.com/protocolbuffers/protobuf/pull/15708
    #   https://github.com/protocolbuffers/protobuf/commit/5722aeffcad72e9a335a3ec7985858dfa31477be
    #   https://github.com/protocolbuffers/protobuf/pull/15671
    #   https://github.com/protocolbuffers/protobuf/commit/8135fca851c76344392c7888e4eb647013b40479
    if [ -e "python/setup.py" ]; then
        # Fake makefile output for CMake build due to hard-coded path in "setup.py".
        [ ! -d 'build' ] || ln -sf '../build' 'src/.libs'

        PROTOC="$(realpath -e 'build/protoc')" "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" \
            protocolbuffers/protobuf/./python,v5.[3.6=v3.19.,3.7=v4.24.]
    else
        "$ROOT_DIR/pkgs/utils/pip_install_from_wheel.sh" "protobuf==$GIT_TAG_VER"
    fi

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/protobuf
)
sudo rm -vf $STAGE/protobuf
sync "$STAGE" || true
