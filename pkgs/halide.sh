# ================================================================
# Compile Halide
# ================================================================

[ -e $STAGE/halide ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" halide/Halide,master
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd Halide

    if ! ldconfig -p | grep libcblas && ldconfig -p | grep libtatlas; then
        pushd apps/linear_algebra/tests
        echo 'link_directories("/usr/lib64/atlas")' > .CMakeLists.txt
        sed 's/cblas/tatlas/' CMakeLists.txt >> .CMakeLists.txt
        mv {.,}CMakeLists.txt
        popd
        git --no-pager diff
    fi

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID-$DISTRO_VERSION_ID" in
        'centos-'* | 'fedora-'* | 'rhel-'* | 'scientific-'*)
            # set +xe
            # . scl_source enable llvm-toolset-7 || exit 1
            # set -xe
            export CC="clang" CXX="clang++"
            ;;
        'debian-10' | 'ubuntu-18.'* | 'ubuntu-19.'*)
            export CC="clang-7" CXX="clang++-7"
            ;;
        'ubuntu-20.'*)
            export CC="clang-10" CXX="clang++-10"
            ;;
        'debian-11' | 'ubuntu-21.04')
            export CC="clang-11" CXX="clang++-11"
            ;;
        'ubuntu-21.10')
            export CC="clang-13" CXX="clang++-13"
            ;;
        'debian-12' | 'ubuntu-22.04')
            export CC="clang-14" CXX="clang++-14"
            ;;
        'ubuntu-24.04')
            export CC="clang-18" CXX="clang++-18"
            ;;
        'debian-13')
            export CC="clang-19" CXX="clang++-19"
            ;;
        'ubuntu-25.'*)
            export CC="clang-20" CXX="clang++-20"
            ;;
        *)
            export CC="clang" CXX="clang++"
            ;;
        esac

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        "$TOOLCHAIN/cmake"                                      \
            -DCMAKE_{EXE,SHARED}_LINKER_FLAGS="-fuse-ld=lld"    \
            -DCMAKE_BUILD_TYPE=Release                          \
            -DCMAKE_C_COMPILER="$CC"                            \
            -DCMAKE_CXX_COMPILER="$CXX"                         \
            -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache       \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"               \
            -DCMAKE_VERBOSE_MAKEFILE=ON                         \
            -DOpenGL_GL_PREFERENCE=GLVND                        \
            -G"Ninja"                                           \
            ..

        set +e
        time "$TOOLCHAIN/cmake" --build . || exit 1
        time "$TOOLCHAIN/ctest" --output-on-failure
        set -e
        time "$TOOLCHAIN/cmake" --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/Halide
)
sudo rm -vf $STAGE/halide
sync "$STAGE" || true
