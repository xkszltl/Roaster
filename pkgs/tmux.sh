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
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            export CC="gcc" CXX="g++"
            ;;
        'ubuntu')
            export CC="gcc-8" CXX="g++-8"
            ;;
        esac

        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

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
    git clone "$GIT_MIRROR/tmux-plugins/tpm" ~/.tmux/plugins/tpm
    cat << EOF > ~/.tmux.conf
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

set -g @resurrect-processes 'watch "/usr/bin/python3 /usr/bin/glances"'
set -g @continuum-restore 'on'

set -g mouse on

run -b '~/.tmux/plugins/tpm/tpm'
EOF

    TMUX_PLUGIN_MANAGER_PATH=~/.tmux/plugins/ ~/.tmux/plugins/tpm/bin/install_plugins
    TMUX_PLUGIN_MANAGER_PATH=~/.tmux/plugins/ ~/.tmux/plugins/tpm/bin/update_plugins all
)
sudo rm -vf $STAGE/tmux
sync || true
