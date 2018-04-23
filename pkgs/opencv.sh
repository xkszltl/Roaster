# ================================================================
# Compile OpenCV
# ================================================================

[ -e $STAGE/opencv ] && ( set -xe
    cd $SCRATCH

    until git clone --depth 1 --single-branch -b "$(git ls-remote --tags "$GIT_MIRROR/opencv/opencv.git" | sed -n 's/.*[[:space:]]refs\/tags\/\([0-9\.]*\)$/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/opencv/opencv.git"; do echo 'Retrying'; done
    cd opencv

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +x
        . scl_source enable devtoolset-6 || true
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        if [ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ]; then
            export HTTP_PROXY=proxy.codingcafe.org:8118
            [ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
            [ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
            [ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY
        fi
        cmake                                               \
            -G"Ninja"                                       \
            -DBUILD_opencv_dnn=OFF                          \
            -DBUILD_opencv_world=OFF                        \
            -DCMAKE_BUILD_TYPE=Release                      \
            -DCMAKE_C_COMPILER_LAUNCHER=ccache              \
            -DCMAKE_C{,XX}_FLAGS="-g"                       \
            -DCMAKE_CXX_COMPILER_LAUNCHER=ccache            \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
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
            -DCUDA_NVCC_FLAGS='--expt-relaxed-constexpr'    \
            -DENABLE_CXX11=ON                               \
            -DINSTALL_CREATE_DISTRIB=ON                     \
            -DOPENCV_ENABLE_NONFREE=ON                      \
            -DOpenGL_GL_PREFERENCE=GLVND                    \
            -DWITH_LIBV4L=ON                                \
            -DWITH_NVCUVID=ON                               \
            -DWITH_OPENGL=ON                                \
            -DWITH_OPENMP=ON                                \
            -DWITH_QT=ON                                    \
            -DWITH_TBB=ON                                   \
            -DWITH_UNICAP=ON                                \
            ..

        time cmake --build . --target install
        # time cmake --build . --target package
        # sudo yum install -y ./OpenCV*.rpm || sudo yum update -y ./OpenCV*.rpm || sudo rpm -ivh --nodeps ./OpenCV*.rpm || sudo rpm -Uvh --nodeps ./OpenCV*.rpm
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/opencv
)
sudo rm -vf $STAGE/opencv
sync || true
