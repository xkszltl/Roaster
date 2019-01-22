# ================================================================
# Shadowsocks
# ================================================================

[ -e $STAGE/ss ] && ( set -xe
    cd "$SCRATCH"
    mkdir -p ss
    cd ss

    if ! $IS_CONTAINER; then
        sudo systemctl enable firewalld
        sudo systemctl status firewalld || sudo systemctl start firewalld
        sudo firewall-cmd --permanent --add-port=8388/tcp
        sudo firewall-cmd --reload
    fi

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" shadowsocks/shadowsocks,master

    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF > shadowsocks.service
[Unit]
Description=Shadowsocks daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ssserver -p 8388 -k sensitive_password_removed -m aes-256-gcm --fast-open
User=nobody

[Install]
WantedBy=multi-user.target
EOF
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF > shadowsocks-client.service
[Unit]
Description=Shadowsocks client daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/sslocal -l 1080 -s sensitive_url_removed -p 8388 -k sensitive_password_removed -m aes-256-gcm --fast-open
User=nobody

[Install]
WantedBy=multi-user.target
EOF
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    sudo install "shadowsocks"{,"-client"}".service" '/usr/lib/systemd/system/'
    sudo systemctl daemon-reload || $IS_CONTAINER
    for i in shadowsocks{,-client}; do :
        sudo systemctl enable $i
        sudo systemctl start $i || $IS_CONTAINER
    done

    # ------------------------------------------------------------

    export SS_KMOD_CONF='90-shadowsocks.conf'
    export SS_SYSCTL_CONF='90-shadowsocks.conf'

    touch $SS_KMOD_CONF

    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF > "$SS_SYSCTL_CONF"
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000

net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
EOF
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    for i in hybla htcp; do
        if modprobe -a tcp_$i; then
            modprobe -a $i || echo $i >> $SS_KMOD_CONF
            echo "net.ipv4.tcp_allowed_congestion_control = $(sysctl -n net.ipv4.tcp_allowed_congestion_control) $i" >> "$SS_SYSCTL_CONF"
        fi
    done

    sudo install "$SS_KMOD_CONF" '/etc/modules-load.d/'
    sudo install "$SS_SYSCTL_CONF" '/etc/sysctl.d/'

    sudo sysctl --system || $IS_CONTAINER
    # sslocal -s sensitive_url_removed -p 8388 -k sensitive_password_removed -m aes-256-gcm --fast-open -d restart

    cd
    rm -rf $SCRATCH/ss
)
sudo rm -vf $STAGE/ss
sync || true
