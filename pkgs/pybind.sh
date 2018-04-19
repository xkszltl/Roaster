# ================================================================
# Compile PyBind11
# ================================================================

[ -e $STAGE/pybind ] && ( set -xe
    cd $SCRATCH

    sudo pip install -U git+$GIT_MIRROR/pytest-dev/pytest.git

    # ------------------------------------------------------------

    until git clone --depth 1 --single-branch -b "$(git ls-remote --tags "$GIT_MIRROR/pybind/pybind11.git" | sed -n 's/.*[[:space:]]refs\/tags\/\(v[0-9\.]*\)[[:space:]]*$/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/pybind/pybind11.git"; do echo 'Retrying'; done
    cd pybind11

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +x
        . scl_source enable devtoolset-7 || true
        set -xe

        mkdir -p build
        cd $_

        cmake                                       \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER_LAUNCHER=ccache      \
            -DCMAKE_C{,XX}_FLAGS="-g"               \
            -DCMAKE_CXX_COMPILER_LAUNCHER=ccache    \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -G"Ninja"                               \
            ..

        time cmake --build .
        time cmake --build . --target test || true
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/pybind11
)
sudo rm -vf $STAGE/pybind
sync || true
