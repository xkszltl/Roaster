# ================================================================
# Compile lm-sensors
# ================================================================

[ -e $STAGE/lm-sensors ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" lm-sensors/lm-sensors,V3
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd lm-sensors

    for arg in CC ETCDIR PREFIX; do
        sed -i 's/^\([[:space:]]*'"$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$arg")"'[[:space:]]*\):=/\1?=/' Makefile
    done
    git commit -am 'Expose build args.'

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        export CC="ccache $CC"
        export CFLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"
        time ETCDIR="$INSTALL_ROOT/etc" PREFIX="$INSTALL_ABS" make -j"$(nproc)"
        time ETCDIR="$INSTALL_ROOT/etc" PREFIX="$INSTALL_ABS" make -j install
    )

    # Keep conflicting files for manual review and overwrite.
    cp -f "$INSTALL_ROOT/etc/sensors3"{,-roaster}".conf"

    # Exclude distro lm-sensors files.
    pushd "$INSTALL_ROOT"
    for i in lm{_,-}sensors; do
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel' | 'scientific')
            [ "$(rpm -qa "$i")" ] || continue
            rpm -ql "$i" | sed -n 's/^\//\.\//p' | xargs rm -rf
            ;;
        'debian' | 'linuxmint' | 'ubuntu')
            dpkg -l "$i" && dpkg -L "$i" | xargs -n1 | xargs -i -n1 find {} -maxdepth 0 -not -type d | sed -n 's/^\//\.\//p' | xargs rm -rf
            ;;
        esac
    done
    popd

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/lm-sensors
)
sudo rm -vf $STAGE/lm-sensors
sync || true
