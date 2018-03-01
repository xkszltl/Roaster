# ================================================================
# Shadowsocks
# ================================================================

[ -e $STAGE/ss ] && ( set -xe
    firewall-cmd --permanent --add-port=8388/tcp
    firewall-cmd --reload

    pip install -U $GIT_MIRROR/shadowsocks/shadowsocks/$([ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ] && echo 'repository/archive.zip?ref=master' || echo 'archive/master.zip')

    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF > /usr/lib/systemd/system/shadowsocks.service
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
    cat << EOF > /usr/lib/systemd/system/shadowsocks-client.service
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

    systemctl daemon-reload || $IS_CONTAINER
    for i in shadowsocks{,-client}; do :
        systemctl enable $i
        systemctl start $i || $IS_CONTAINER
    done

    # ------------------------------------------------------------

    export SS_KMOD_CONF='/etc/modules-load.d/90-shadowsocks.conf'
    export SS_SYSCTL_CONF='/etc/sysctl.d/90-shadowsocks.conf'

    truncate -s0 $SS_KMOD_CONF $SS_SYSCTL_CONF

    for i in tcp_{htcp,hybla}; do
        modprobe -a $i || echo $i >> $SS_KMOD_CONF
    done

    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF >> $SS_SYSCTL_CONF
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

    for i in htcp hybla; do
        if modprobe -a tcp_$i; then
            echo "net.ipv4.tcp_allowed_congestion_control = $(sysctl -n net.ipv4.tcp_allowed_congestion_control) $i" >> $SS_SYSCTL_CONF
            echo "net.ipv4.tcp_congestion_control = $i"
            break
        fi
    done

    sysctl --system || $IS_CONTAINER
    # sslocal -s sensitive_url_removed -p 8388 -k sensitive_password_removed -m aes-256-gcm --fast-open -d restart
)
rm -rvf $STAGE/ss
sync || true
