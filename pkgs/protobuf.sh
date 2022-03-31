# ================================================================
# Compile Protobuf
# ================================================================

[ -e $STAGE/protobuf ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" benjaminp/six

    # ------------------------------------------------------------

    # Known issues:
    #   - Protobuf 3.20 drops Python 3.6 support.
    #     https://github.com/protocolbuffers/protobuf/pull/9480
    #     https://github.com/protocolbuffers/protobuf/commit/301d315dc4674d1bc799446644e88eff0af1ac86
    . "$ROOT_DIR/pkgs/utils/git/version.sh" "protocolbuffers/protobuf,v$(! python3 --version | cut -d' ' -f2 | grep '^3\.[0-6]\.' >/dev/null || echo '3.19.')"
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
            export C{,XX}FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -fPIC -O3 -g"

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
    if [ -d "build" ]; then
        pushd src
        ln -sf ../build .libs
        popd
    fi

    # for py in ,python3 rh-python38,python; do
    for py in ,python3; do
    (
        py="$py,"

        case "$DISTRO_ID-$DISTRO_VERSION_ID" in
        'centos-'* | 'fedora-'* | 'rhel-'* | 'scientific-'*)
            set +xe
            . scl_source enable devtoolset-9 $(cut -d',' -f1 <<< "$py") || exit 1
            set -xe
            export CC="gcc" CXX="g++"
            ;;
        'debian-10' | 'ubuntu-18.'* | 'ubuntu-19.'*)
            # Skip SCL Python.
            [ "$(cut -d',' -f1 <<< "$py")" ] && continue
            export CC="gcc-8" CXX="g++-8" FC="gfortran-8"
            ;;
        'debian-11' | 'ubuntu-20.'* | 'ubuntu-21.'*)
            # Skip SCL Python.
            [ "$(cut -d',' -f1 <<< "$py")" ] && continue
            export CC="gcc-10" CXX="g++-10" FC="gfortran-10"
            ;;
        esac

        py="$(which "$(cut -d',' -f2 <<< "$py")")"

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        export CC="$TOOLCHAIN/$CC"
        export CXX="$TOOLCHAIN/$CXX"
        export LD="$TOOLCHAIN/ld"

        export PROTOC="$(realpath -e ./protoc)"

        pushd python
        git clean -dfx .
        "$py" ./setup.py bdist_wheel --cpp_implementation
        sudo "$py" -m pip install -IU dist/*.whl
        popd
    )
    done

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/protobuf
)
sudo rm -vf $STAGE/protobuf
sync || true
