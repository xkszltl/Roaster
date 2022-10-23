# ================================================================
# Compile x265 codec
# ================================================================

[ -e $STAGE/x265 ] && ( set -xe
    cd $SCRATCH

    [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ]                      \
    && . "$ROOT_DIR/pkgs/utils/git/version.sh" multicoreware/x265_git,  \
    || GIT_MIRROR="https://bitbucket.org" . "$ROOT_DIR/pkgs/utils/git/version.sh" multicoreware/x265_git,
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO" x265; do echo 'Retrying'; done
    cd x265

    # ------------------------------------------------------------

    ./version.sh                                                                                    \
    | sed -n 's/^[[:space:]]*#define[[:space:]][[:space:]]*X264_POINTVER[[:space:]][[:space:]]*//p' \
    | tr -d '"'                                                                                     \
    | tr '[:space:]' '\t'                                                                           \
    | cut -f1                                                                                       \
    | grep .                                                                                        \
    | head -n1                                                                                      \
    | xargs -I{} git tag {}

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set -e

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        # Order sensitive multilib build.
        # The last one will be exported as default C API.
        # Others are hidden in depth-tagged C++ namespaces.
        for depth in 12 10 8; do
            mkdir -p build-"$depth"bit
            pushd "$_"

            "$TOOLCHAIN/cmake"                                  \
                -DCMAKE_BUILD_TYPE=Release                      \
                -DCMAKE_C_COMPILER="$CC"                        \
                -DCMAKE_CXX_COMPILER="$CXX"                     \
                -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache   \
                -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
                -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
                -DENABLE_CLI="$(    [ "$depth" -le  8 ] && echo ON || echo OFF)"    \
                -DENABLE_HDR10_PLUS=ON                          \
                -DENABLE_SHARED=ON                              \
                -DENABLE_SVT_HEVC=ON                            \
                -DENABLE_TESTS="$(  [ "$depth" -le  8 ] && echo ON || echo OFF)"    \
                -DEXPORT_C_API="$(  [ "$depth" -le  8 ] && echo ON || echo OFF)"    \
                -DEXTRA_LIB="$(set -e
                        find .. -maxdepth 2 -name 'libx265.a' -type f               \
                        | xargs -rI{} realpath -e {}                                \
                        | paste -sd';' -
                    )"                                          \
                -DLINKED_10BIT="$(  [ "$depth" -lt 10 ] && echo ON || echo OFF)"    \
                -DLINKED_12BIT="$(  [ "$depth" -lt 12 ] && echo ON || echo OFF)"    \
                -DHIGH_BIT_DEPTH="$([ "$depth" -gt  8 ] && echo ON || echo OFF)"    \
                -DMAIN12="$(        [ "$depth" -eq 12 ] && echo ON || echo OFF)"    \
                -G"Ninja"                                       \
                ../source

            time "$TOOLCHAIN/cmake" --build .
            [ "$depth" -gt 8 ] || time test/TestBench
            [ "$depth" -gt 8 ] || time "$TOOLCHAIN/cmake" --build . --target install
            [ "$depth" -gt 8 ] || ./x265 --version 2>&1 | grep 8bit | grep 10bit | grep 12bit

            popd
        done
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/x265
)
sudo rm -vf $STAGE/x265
sync || true
