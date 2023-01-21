# ================================================================
# Compile ONNX
# ================================================================

[ -e $STAGE/onnx ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh"  \
        cython/cython                               \
        benjaminp/six                               \
        'pytest-dev/pytest,[3.6=7.0.]'              \
        'numpy/numpy,v[3.6=v1.19.|3.7=v1.21.]'      \
        'mesonbuild/meson,[3.6=]'

    # Known issues:
    # - SciPy meson build uses the wrong casing of OpenBLAS for CMake.
    #   On Debian, pkg-config also searches in /usr/local and works as a fallback, but not on CentOS 7.
    #   https://github.com/scipy/scipy/issues/16308
    (
        set -xe

        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel' | 'scientific')
            export PKG_CONFIG_PATH="$(rpm -ql roaster-openblas | grep -v '/src/' | grep '\.pc' | xargs -rI{} dirname {} | sort -u | paste -sd: -)"
            ;;
        'debian' | 'linuxmint' | 'ubuntu')
            export PKG_CONFIG_PATH="$(dpkg -L roaster-openblas | grep -v '/src/' | grep '\.pc' | xargs -rI{} dirname {} | sort -u | paste -sd: -)"
            ;;
        esac

        "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh"  \
            'scipy/scipy,v[3.6=v1.5.|3.7=v1.7.]'
    )

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh"  \
        'scikit-learn/scikit-learn,[3.6=0.24.|3.7=1.0.]'

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" onnx/onnx,v
    until git clone -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done

    cd onnx

    git remote add patch "$GIT_MIRROR/xkszltl/onnx.git"

    # Patches:
    # - Google benchmark 1.4.1 failed to compile with gcc-11.
    #   https://github.com/onnx/onnx/issues/4144
    PATCHES=""
    for i in $PATCHES; do
        git fetch patch "$i"
        git cherry-pick FETCH_HEAD
    done

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # pushd third_party/pybind11
    # git checkout master
    # rm -rf pybind11
    # cp -rf /usr/local/src/pybind11 pybind11
    # popd

    # git commit -am "Update submodule \"pybind11\"."

    (
        set -xe

        cd cmake/external

        for i in ./*.cmake; do
            sed -i "s/$(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR_GITHUB")\(\/..*\/.*\.git\)/$(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR")\1/" "$i"
        done
        git --no-pager diff
    )

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        mkdir -p build
        pushd $_

        (
            set -e
            # Known issues:
            # - ONNX 1.13.0 requires Protobuf 3.20.2 incompatible with Python 3.6.
            case "$DISTRO_ID-$DISTRO_VERSION_ID" in
            'centos-'* | 'fedora-'* | 'rhel-'* | 'scientific-'*)
                set +xe
                . scl_source enable rh-python38 || exit 1
                set -xe
                ;;
            esac

            "$TOOLCHAIN/cmake"                          \
                -DBENCHMARK_ENABLE_LTO=ON               \
                -DBUILD_ONNX_PYTHON=ON                  \
                -DBUILD_SHARED_LIBS=ON                  \
                -DCMAKE_BUILD_TYPE=Release              \
                -DCMAKE_C_COMPILER="$CC"                \
                -DCMAKE_CXX_COMPILER="$CXX"             \
                -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
                -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
                -DONNX_BUILD_BENCHMARKS=ON              \
                -DONNX_BUILD_TESTS=ON                   \
                -DONNX_GEN_PB_TYPE_STUBS=ON             \
                -DONNX_ML=ON                            \
                -DONNX_USE_PROTOBUF_SHARED_LIBS=ON      \
                -DONNXIFI_ENABLE_EXT=ON                 \
                -G"Ninja"                               \
                ..

            time "$TOOLCHAIN/cmake" --build .
            time ./onnx_gtests
            time "$TOOLCHAIN/cmake" --build . --target install
        )

        popd

        (
            set -e
            export PY_VER='^3\.[7-9],^3\.[1-6][0-9]'
            case "$DISTRO_ID-$DISTRO_VERSION_ID" in
            'debian-'* | 'linuxmint-'* | 'ubuntu-'*)
                # Already pinned to a Python3.6-compatible version.
                ! python3 --version | cut -d' ' -f2 | grep '^3\.[0-6]\.' >/dev/null || export PY_VER=''
                ;;
            esac
            CMAKE_ARGS="$CMAKE_ARGS
                -DBUILD_SHARED_LIBS=ON
                -DCMAKE_BUILD_TYPE=Release
                -DCMAKE_C_COMPILER='$(which "$CC")'
                -DCMAKE_C_COMPILER_LAUNCHER=ccache
                -DCMAKE_CXX_COMPILER='$(which "$CXX")'
                -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
                -DONNX_BUILD_TESTS=ON
                -DONNX_GEN_PB_TYPE_STUBS=ON
                -DONNX_USE_PROTOBUF_SHARED_LIBS=ON
                -DONNXIFI_ENABLE_EXT=ON
            " ONNX_ML=1 "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" .
        )
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/onnx

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" microsoft/onnxconverter-common,v onnx/{keras,sklearn}-onnx,v onnx/onnxmltools,
)
sudo rm -vf $STAGE/onnx
sync || true
