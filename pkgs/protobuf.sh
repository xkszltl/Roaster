# ================================================================
# Compile Protobuf
# ================================================================

[ -e $STAGE/protobuf ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" benjaminp/six

    # ------------------------------------------------------------

    # v3.6.1.3 has issues with CMake on Linux.
    . "$ROOT_DIR/pkgs/utils/git/version.sh" protocolbuffers/protobuf,master
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd protobuf

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7 rh-python36
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        if false; then
            export CC="ccache gcc"
            export CXX="ccache g++"
            export C{,XX}FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -fPIC -O3 -g" 

            ./autogen.sh
            ./configure --prefix="$INSTALL_ABS"
            make -j$(nproc)
            make check -j$(nproc)
            make install -j
        else
            mkdir -p build
            cd $_

            cmake                                       \
                -DBUILD_SHARED_LIBS=ON                  \
                -DCMAKE_BUILD_TYPE=Release              \
                -DCMAKE_C_COMPILER=gcc                  \
                -DCMAKE_CXX_COMPILER=g++                \
                -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
                -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g -DPYTHON_PROTO2_CPP_IMPL_V2"   \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
                -Dprotobuf_BUILD_EXAMPLES=ON            \
                -Dprotobuf_INSTALL_EXAMPLES=ON          \
                -G"Ninja"                               \
                ../cmake

            time cmake --build .
            time cmake --build . --target check
            time cmake --build . --target install
        fi

        (
            set -e

            # Fake makefile output for CMake build due to hard-coded path in "setup.py".
            pushd ../src
            ln -sf ../build .libs
            popd

            export CC="$TOOLCHAIN/gcc"
            export CXX="$TOOLCHAIN/g++"
            export LD="$TOOLCHAIN/ld"

            export PROTOC="$(readlink -e ./protoc)"

            pushd ../python
            python ./setup.py bdist_wheel --cpp_implementation
            sudo python -m pip install -IU dist/*.whl
            popd
        )
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/protobuf
)
sudo rm -vf $STAGE/protobuf
sync || true
