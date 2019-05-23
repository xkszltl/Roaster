# ================================================================
# Shadowsocks
# ================================================================

[ -e $STAGE/ss ] && ( set -xe
    cd "$SCRATCH"

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" shadowsocks/shadowsocks,master

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" shadowsocks/shadowsocks,master
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd shadowsocks

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    # ------------------------------------------------------------
    # Config
    # ------------------------------------------------------------
    (
        set -xe
        mkdir -p "$INSTALL_ROOT/etc/shadowsocks"
        cd $_

        jq -n '
        {
            "server":           "0.0.0.0",
            "server_port":      '"$CRED_USR_SS_PORT"',
            "password":         "'"$CRED_USR_SS_PWD"'",
            "method":           "aes-256-gcm",
            "fast_open":        true
        }' > 'ssserver.json'

        jq -n '
        {
            "server":           "'"$CRED_USR_SS_ADDR"'",
            "server_port":      '"$CRED_USR_SS_PORT"',
            "local_address":    "127.0.0.1",
            "local_port":       1080,
            "password":         "'"$CRED_USR_SS_PWD"'",
            "method":           "aes-256-gcm",
            "fast_open":        true
        }' > 'sslocal.json'
    )

    # ------------------------------------------------------------
    # Sytemd
    # ------------------------------------------------------------
    (
        set -xe
        mkdir -p "$INSTALL_ROOT/usr/lib/systemd/system"
        cd $_

        # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        cat << EOF > shadowsocks.service
[Unit]
Description=Shadowsocks daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ssserver -c /etc/shadowsocks/ssserver.json
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
ExecStart=/usr/local/bin/sslocal -c /etc/shadowsocks/sslocal.json
User=nobody

[Install]
WantedBy=multi-user.target
EOF
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    )

    # ------------------------------------------------------------
    # Load kmod
    # ------------------------------------------------------------
    (
        set -xe
        mkdir -p "$INSTALL_ROOT/etc/modules-load.d"
        cd "$_"

        SS_CONF='90-shadowsocks.conf'

        touch "$SS_CONF"
        for i in hybla htcp; do
            if modprobe -a "tcp_$i"; then
                echo $i >> "$SS_CONF"
            fi
        done
    )

    # ------------------------------------------------------------
    # Configure sysctl
    # ------------------------------------------------------------
    (
        set -xe
        mkdir -p "$INSTALL_ROOT/etc/sysctl.d"
        cd "$_"

        SS_CONF='90-shadowsocks.conf'

        # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        cat << EOF > "$SS_CONF"
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
            if modprobe -a "tcp_$i"; then
                echo "net.ipv4.tcp_allowed_congestion_control = $(sysctl -n net.ipv4.tcp_allowed_congestion_control) $i" >> "$SS_CONF"
            fi
        done
    )

    # ------------------------------------------------------------

    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    echo > "$INSTALL_ROOT/../fpm/post_install.sh" "
export SS_PORT='$CRED_USR_SS_PORT/tcp'

systemctl enable firewalld || $IS_CONTAINER
systemctl status firewalld || systemctl start firewalld || $IS_CONTAINER
if [ -f '/etc/shadowsocks/ssserver.json' ]; then
    firewall-cmd --permanent --add-port="\$SS_PORT" || $IS_CONTAINER
else
    firewall-cmd --permanent --remove-port="\$SS_PORT" || $IS_CONTAINER
fi
firewall-cmd --reload || $IS_CONTAINER

for i in shadowsocks{,-client}; do
    if [ -f '/etc/shadowsocks/ssserver.json' ]; then
        systemctl enable \$i
        systemctl start \$i || $IS_CONTAINER
    else
        systemctl disable \$i
        systemctl stop \$i || $IS_CONTAINER
    fi
done
"
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/shadowsocks
)
sudo rm -vf $STAGE/ss
sync || true
