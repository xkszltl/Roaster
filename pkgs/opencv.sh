# ================================================================
# Compile OpenCV
# ================================================================

[ -e $STAGE/opencv ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" opencv/opencv,
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd opencv

    # ------------------------------------------------------------

    git submodule add "../opencv_contrib.git" contrib
    pushd contrib
    git checkout "$GIT_TAG"
    popd
    git commit -am "Add opencv_contrib as submodule"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-9 rh-git218 || exit 1
            set -xe
            export CC="gcc" CXX="g++" AR="$(which gcc-ar)" RANLIB="$(which gcc-ranlib)"
            ;;
        'ubuntu')
            export CC="gcc-8" CXX="g++-8" AR="$(which gcc-ar-8)" RANLIB="$(which gcc-ranlib-8)"
            ;;
        esac

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        if [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ]; then
            # export HTTP_PROXY=proxy.codingcafe.org:8118
            [ "$HTTP_PROXY" ] && export HTTPS_PROXY="$HTTP_PROXY"
            [ "$HTTP_PROXY" ] && export http_proxy="$HTTP_PROXY"
            [ "$HTTPS_PROXY" ] && export https_proxy="$HTTPS_PROXY"

            # Use mirrored download path in opencv cmake.
            (
                set -xe
                GITHUB_RAW='https://raw.githubusercontent.com'
                git grep --name-only --recurse-submodules "$GITHUB_RAW" -- '*.cmake' '*/CMakeLists.txt' \
                | xargs -n1 sed -i "s/$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$GITHUB_RAW")\(\/[^\/]*\/[^\/]*\)/$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$GIT_MIRROR")\1\/raw/"
            )
        fi

        mkdir -p build
        cd $_

        # --------------------------------------------------------
        # Known issues:
        #   - Official FindPNG.cmake prefers /lib64/libpng.so on CentOS.
        #     Override with CMAKE_LIBRARY_PATH.
        #   - Separable CUDA causes symbol redefinition.
        # --------------------------------------------------------

        cmake                                               \
            -DBUILD_PROTOBUF=OFF                            \
            -DBUILD_WITH_DEBUG_INFO=ON                      \
            -DBUILD_opencv_world=OFF                        \
            -DBUILD_opencv_dnn=OFF                          \
            -DCMAKE_BUILD_TYPE=Release                      \
            -DCMAKE_AR="$AR"                                \
            -DCMAKE_C_COMPILER="$CC"                        \
            -DCMAKE_CXX_COMPILER="$CXX"                     \
            -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache   \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
            -DCMAKE_LIBRARY_PATH='/usr/local/lib64;/usr/local/lib;/usr/local/lib32'         \
            -DCMAKE_RANLIB="$RANLIB"                        \
            -DCMAKE_VERBOSE_MAKEFILE=ON                     \
            -DCPACK_BINARY_DEB=OFF                          \
            -DCPACK_BINARY_RPM=ON                           \
            -DCPACK_BINARY_STGZ=OFF                         \
            -DCPACK_BINARY_TBZ2=OFF                         \
            -DCPACK_BINARY_TGZ=OFF                          \
            -DCPACK_BINARY_TXZ=OFF                          \
            -DCPACK_BINARY_TZ=OFF                           \
            -DCPACK_SET_DESTDIR=ON                          \
            -DCPACK_SOURCE_RPM=ON                           \
            -DCPACK_SOURCE_STGZ=OFF                         \
            -DCPACK_SOURCE_TBZ2=OFF                         \
            -DCPACK_SOURCE_TGZ=OFF                          \
            -DCPACK_SOURCE_TXZ=OFF                          \
            -DCPACK_SOURCE_ZIP=OFF                          \
            "$($TOOLCHAIN_CPU_NATIVE || echo "-DCPU_BASELINE=AVX")"         \
            "$($TOOLCHAIN_CPU_NATIVE || echo "-DCPU_DISPATCH='FP16;AVX2'")" \
            -DCUDA_NVCC_FLAGS='--expt-relaxed-constexpr'    \
            -DCUDA_SEPARABLE_COMPILATION=OFF                \
            -DENABLE_CCACHE=ON                              \
            -DENABLE_CXX11=ON                               \
            -DENABLE_LTO=ON                                 \
            -DENABLE_PRECOMPILED_HEADERS=ON                 \
            -DINSTALL_CREATE_DISTRIB=ON                     \
            -DINSTALL_TESTS=ON                              \
            -DMKL_WITH_OPENMP=ON                            \
            -DOPENCV_ENABLE_NONFREE=ON                      \
            -DOPENCV_EXTRA_MODULES_PATH='../contrib/modules'\
            -DOpenGL_GL_PREFERENCE=GLVND                    \
            -DPROTOBUF_UPDATE_FILES=ON                      \
            -DWITH_HALIDE=ON                                \
            -DWITH_LIBV4L=ON                                \
            -DWITH_MKL=ON                                   \
            -DWITH_NVCUVID=ON                               \
            -DWITH_OPENGL=ON                                \
            -DWITH_OPENMP=ON                                \
            -DWITH_QT=ON                                    \
            -DWITH_UNICAP=ON                                \
            -DWITH_VULKAN=ON                                \
            -G"Ninja"                                       \
            ..

        time cmake --build . --target install
        # time cmake --build . --target package
        # sudo dnf install -y ./OpenCV*.rpm || sudo dnf update -y ./OpenCV*.rpm || sudo rpm -ivh --nodeps ./OpenCV*.rpm || sudo rpm -Uvh --nodeps ./OpenCV*.rpm
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/opencv
)
sudo rm -vf $STAGE/opencv
sync || true
