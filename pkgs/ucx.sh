# ================================================================
# GDRCopy
# ================================================================

[ -e $STAGE/ucx ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" openucx/ucx,v
    until git clone -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd ucx

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"


    # Known issues:
    #   - Patch v1.9.0 for Java 11 (Ubuntu default).
    #     https://github.com/openucx/ucx/issues/5811
    #     https://github.com/openucx/ucx/commit/3fe3502fe5b925ac11cc18d564265384ee544701
    #   - Patch v1.9.0 for javadoc path:
    #     https://github.com/openucx/ucx/issues/5858
    #     https://github.com/openucx/ucx/commit/84c73e34454f96d7eb8887cec6435d4474ded756
    #     https://github.com/openucx/ucx/commit/a1cf7c54f6c427c027605d732aa230bd50e405c5
    #   - Header mismatched between ucg and ucs in v1.9.0.
    #     https://github.com/openucx/ucx/issues/5810

    git cherry-pick 3fe3502
    git cherry-pick 84c73e3
    git cherry-pick a1cf7c5

    pushd src/ucg
    git checkout master
    git submodule update --init
    popd
    git --no-pager diff
    git commit -am "Automatic git submodule updates."

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-9 || exit 1
            set -xe
            export CC="ccache $(which gcc)" CXX="ccache $(which g++)"
            ;;
        'ubuntu')
            export CC="ccache $(which gcc-8)" CXX="ccache $(which g++-8)"
            ;;
        esac
        export CFLAGS="  $CFLAGS   -O3 -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"
        export CXXFLAGS="$CXXFLAGS -O3 -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"

        cuda_nvcc="$(which nvcc || echo /usr/local/cuda/bin/nvcc)"
        cuda_root="$("$cuda_nvcc" --version > /dev/null && readlink -e "$(dirname "$cuda_nvcc")/..")"

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
