# ================================================================
# Compile Protobuf
# ================================================================

[ -e $STAGE/protobuf ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" google/protobuf,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd protobuf

    if [ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ]; then
        export HTTP_PROXY=proxy.codingcafe.org:8118
        [ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
        [ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
        [ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY
        for i in google; do
            sed -i "s/[^[:space:]]*:\/\/[^\/]*\(\/$i\/.*\)/$(sed 's/\//\\\//g' <<<$GIT_MIRROR )\1.git/" .gitmodules
            sed -i "s/\($(sed 's/\//\\\//g' <<<$GIT_MIRROR )\/$i\/.*\.git\)\.git[[:space:]]*$/\1/" .gitmodules
        done
    fi

    git submodule init
    until git config --file .gitmodules --get-regexp path | cut -d' ' -f2 | parallel -j0 --ungroup --bar '[ ! -d "{}" ] || git submodule update --recursive "{}"'; do echo 'Retrying'; done

    if false; then
        until git clone --depth 1 --single-branch --recursive -b "$(git ls-remote --tags "$GIT_MIRROR/google/googletest.git" | sed -n 's/.*[[:space:]]refs\/tags\/\(release-[0-9\.]*\)$/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/google/googletest.git"; do echo 'Retrying'; done
        rm -rf gmock
        mkdir -p $_
        pushd $_
        ln -sf ../googletest/googlemock/* .
        ln -sf ../googletest/googletest gtest
        popd
    fi

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        set -xe
        # ./autogen.sh
        # ./configure --prefix="$INSTALL_ABS"
        # make -j$(nproc)
        # make check -j$(nproc)
        # make install -j

        mkdir -p build
        cd $_

        cmake                                       \
            -DBUILD_SHARED_LIBS=ON                  \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-g"               \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -Dprotobuf_BUILD_EXAMPLES=ON            \
            -Dprotobuf_INSTALL_EXAMPLES=ON          \
            -G"Ninja"                               \
            ../cmake

        time cmake --build .
        time cmake --build . --target check
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/protobuf
)
sudo rm -vf $STAGE/protobuf
sync || true
