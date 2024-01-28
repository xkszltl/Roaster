# ================================================================
# Compile Trojan
# ================================================================

[ -e $STAGE/trojan ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" trojan-gfw/trojan,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd trojan

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        mkdir -p build
        cd $_

        "$TOOLCHAIN/cmake"                              \
            -DCMAKE_BUILD_TYPE=Release                  \
            -DCMAKE_C_COMPILER="$CC"                    \
            -DCMAKE_CXX_COMPILER="$CXX"                 \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache     \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"       \
            -DDEFAULT_CONFIG='/etc/trojan/config.json'  \
            -DSYSTEMD_SERVICE=ON                        \
            -DSYSTEMD_SERVICE_PATH="$INSTALL_ROOT/usr/lib/systemd/system"   \
            -G"Ninja"                                   \
            ..

        time "$TOOLCHAIN/cmake" --build .
        # Parallel test does not work as of v1.16.0.
        time "$TOOLCHAIN/ctest" --output-on-failure -j1
        time "$TOOLCHAIN/cmake" --build . --target install
    )

    # Remove default config.
    rm -rf "$INSTALL_ABS/etc"

    # Copy sample config to /etc.
    mkdir -p "$INSTALL_ROOT/etc/trojan"
    find -L 'examples/' -mindepth 1 -maxdepth 1 -name '*.json-example' -type f  \
    | xargs -rI{} basename {}                                                   \
    | sed 's/\-example$//'                                                      \
    | sort -u                                                                   \
    | xargs -rI{} cp -f 'examples/{}-example' "$INSTALL_ROOT/etc/trojan/{}"

    # Patch installation paths in systemd services.
    find -L "$INSTALL_ROOT/" -name "*.service" -type f  \
    | xargs -rI{} sed -i "s/$(printf '%s\n' "$INSTALL_ROOT" | sed 's/\/*$//' | sed 's/\([\\\/\.\-]\)/\\\1/g')\//\//g" {}
    find -L "$INSTALL_ROOT/" -name "*.service" -type f  \
    | xargs -rI{} sed -i "s/\/usr\/local\(\/etc\/trojan\/\)/\1/g" {}

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/trojan
)
sudo rm -vf $STAGE/trojan
sync "$STAGE" || true