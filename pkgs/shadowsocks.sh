# ================================================================
# Shadowsocks
# ================================================================

[ -e $STAGE/ss ] && ( set -e
    pip install $GIT_MIRROR/shadowsocks/shadowsocks/$([ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ] && echo 'repository/archive.zip?ref=master' || echo 'archive/master.zip')

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

    truncate -s0 /etc/modules-load.d/90-shadowsocks.conf
    for i in tcp_{htcp,hybla}; do
        modprobe -a $i || echo $i >> /etc/modules-load.d/90-shadowsocks.conf
    done

    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF > /etc/sysctl.d/90-shadowsocks.conf
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
net.ipv4.tcp_congestion_control = htcp
EOF
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    sysctl --system
    # sslocal -s sensitive_url_removed -p 8388 -k sensitive_password_removed -m aes-256-gcm --fast-open -d restart
)
rm -rvf $STAGE/ss
sync || true
