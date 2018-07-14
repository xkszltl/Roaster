# ================================================================
# Compile Halide
# ================================================================

[ -e $STAGE/halide ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    until git clone --depth 1 --single-branch -b "$(git ls-remote --tags "$GIT_MIRROR/halide/Halide.git" | sed -n 's/.*[[:space:]]refs\/tags\/\(release[0-9\._]*\)[[:space:]]*$/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/halide/Halide.git"; do echo 'Retrying'; done
    cd Halide

    if ! ldconfig -p | grep libcblas && ldconfig -p | grep libtatlas; then
        pushd apps/linear_algebra/tests
        echo 'link_directories("/usr/lib64/atlas")' > .CMakeLists.txt
        sed 's/cblas/tatlas/' CMakeLists.txt >> .CMakeLists.txt
        mv {.,}CMakeLists.txt
        popd
        git diff
    fi

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        mkdir -p build
        cd $_

        cmake                                                   \
            -DCMAKE_{EXE,SHARED}_LINKER_FLAGS="-fuse-ld=lld"    \
            -DCMAKE_BUILD_TYPE=Release                          \
            -DCMAKE_C_COMPILER=clang                            \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache             \
            -DCMAKE_C{,XX}_FLAGS="-g"                           \
            -DCMAKE_CXX_COMPILER=clang++                        \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"               \
            -DCMAKE_VERBOSE_MAKEFILE=ON                         \
            -DOpenGL_GL_PREFERENCE=GLVND                        \
            -G"Ninja"                                           \
            ..

        set +e
        time cmake --build . || exit 1
        time cmake --build . --target test
        set -e
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"
    
    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/halide
)
sudo rm -vf $STAGE/halide
sync || true
