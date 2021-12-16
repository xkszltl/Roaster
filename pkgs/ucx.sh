# ================================================================
# GDRCopy
# ================================================================

[ -e $STAGE/ucx ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" openucx/ucx,v
    until git clone -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd ucx

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    pushd src/ucg
    git checkout master
    git submodule update --init
    popd
    git --no-pager diff
    git commit -am "Automatic git submodule updates."

    # ------------------------------------------------------------

    "$ROOT_DIR/geo/maven-mirror.sh"
    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        export CC="$TOOLCHAIN/$(basename "$CC")" CXX="$TOOLCHAIN/$(basename "$CXX")"
        export CFLAGS="  $CFLAGS   -O3 -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"
        export CXXFLAGS="$CXXFLAGS -O3 -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"

        cuda_nvcc="$(which nvcc || echo /usr/local/cuda/bin/nvcc)"
        [ ! -x "$cuda_nvcc" ] || cuda_root="$("$cuda_nvcc" --version > /dev/null && realpath -e "$(dirname "$cuda_nvcc")/..")"

        ./autogen.sh
        ./configure                     \
            --disable-assertions        \
            --disable-logging           \
            --disable-params-check      \
            --enable-backtrace-detail   \
            --enable-compiler-opt=3     \
            --enable-devel-headers      \
            --enable-doxygen-doc=no     \
            --enable-doxygen-dot=no     \
            --enable-doxygen-man=no     \
            --enable-examples           \
            --enable-gtest              \
            --enable-mt                 \
            --enable-ucg=no             \
            --prefix="$INSTALL_ABS"     \
            --with-avx                  \
            "$(sed 's/\(..*\)/--with-cuda=\1/' <<< "$cuda_root")"   \
            --with-gdrcopy=no           \
            "$(javac -version > /dev/null && echo '--with-java')"

        make all docs -j$(nproc)
        make install -j
        # Unit tests take too long to run.
        # make gtest -j$(nproc)

        find "$INSTALL_ABS" -name '*.la' | xargs -r sed -i "s/$(sed 's/\([\\\/\-\.]\)/\\\1/g' <<< "$INSTALL_ROOT")//g"
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCHA/ucx
)
sudo rm -vf $STAGE/ucx
sync || true
