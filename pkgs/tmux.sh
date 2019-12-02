# ================================================================
# Account Configuration
# ================================================================

[ -e $STAGE/tmux ] && ( set -xe
    cd
    rm -rf ~/.tmux/plugins/tpm
    git clone "$GIT_MIRROR/tmux-plugins/tpm" ~/.tmux/plugins/tpm
    cat << EOF > ~/.tmux.conf
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

set -g @resurrect-processes 'watch "/usr/bin/python3 /usr/bin/glances"'
set -g @continuum-restore 'on'

set -g mouse-utf8 on
set -g mouse on

run -b '~/.tmux/plugins/tpm/tpm'
EOF
)
sudo rm -vf $STAGE/tmux
sync || true
