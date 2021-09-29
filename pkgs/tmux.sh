# ================================================================
# Account Configuration
# ================================================================

[ -e $STAGE/tmux ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" tmux/tmux,
    until git clone -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd tmux

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        export CFLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"
        ./autogen.sh
        time ./configure                \
            --prefix="$INSTALL_ABS"
        time make -j$(nproc)
        time make install -j
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/tmux

    mkdir -p ~/.tmux/plugins
    rm -rf ~/.tmux/plugins/tpm
    git clone "$GIT_MIRROR/tmux-plugins/tpm.git" ~/.tmux/plugins/tpm
    cat << EOF > ~/.tmux.conf
set -g @plugin '$GIT_MIRROR/tmux-plugins/tpm.git'
set -g @plugin '$GIT_MIRROR/tmux-plugins/tmux-sensible.git'
set -g @plugin '$GIT_MIRROR/tmux-plugins/tmux-resurrect.git'
set -g @plugin '$GIT_MIRROR/tmux-plugins/tmux-continuum.git'

set -g @resurrect-processes 'watch "/usr/bin/python3 /usr/bin/glances"'
set -g @continuum-restore 'on'

set -g mouse on

run -b '~/.tmux/plugins/tpm/tpm'
EOF

    for attempt in $(seq 100 -1 0); do
        [ "$attempt" -gt 0 ]
        TMUX_PLUGIN_MANAGER_PATH=~/.tmux/plugins/ ~/.tmux/plugins/tpm/bin/install_plugins && break
        echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
        sleep 3
    done
    for attempt in $(seq 100 -1 0); do
        [ "$attempt" -gt 0 ]
        TMUX_PLUGIN_MANAGER_PATH=~/.tmux/plugins/ ~/.tmux/plugins/tpm/bin/update_plugins all && break
        echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
        sleep 3
    done
    sed -i "s/$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$GIT_MIRROR")/$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$GIT_MIRROR_GITHUB")/" ~/.tmux.conf
)
sudo rm -vf $STAGE/tmux
sync || true
