# ================================================================
# Shadowsocks
# ================================================================

[ -e $STAGE/ss ] && ( set -xe
    cd "$SCRATCH"

    # ------------------------------------------------------------

    SS_IMPL="-libev";

    [ "$SS_IMPL" ] || "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" shadowsocks/shadowsocks,master

    . "$ROOT_DIR/pkgs/utils/git/version.sh" "shadowsocks/shadowsocks$SS_IMPL,master"

    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO" shadowsocks; do echo 'Retrying'; done
    cd shadowsocks

    echo 'install(TARGETS bloom-shared cork-shared ipset-shared LIBRARY DESTINATION lib)' >> CMakeLists.txt
    git commit -am 'Patch https://github.com/shadowsocks/shadowsocks-libev/issues/2808 for missing 3rd-party shared libs in installation.'

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    if [ "_$SS_IMPL" = '_-libev' ]; then
    (
        set -e

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        mkdir -p build
        cd $_

        "$TOOLCHAIN/cmake"                          \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DWITH_STATIC=OFF                       \
            -G"Ninja"                               \
            ..

        time "$TOOLCHAIN/cmake" --build .
        time "$TOOLCHAIN/cmake" --build . --target install
    )
    fi

    # ------------------------------------------------------------
    # Config
    # ------------------------------------------------------------
    (
        set -xe
        mkdir -p "$INSTALL_ROOT/etc/shadowsocks"
        cd $_

        jq -n '
        {
            "server":           ["0.0.0.0","::0"],
            "server_port":      '"$CRED_USR_SS_PORT"',
            "password":         "'"$CRED_USR_SS_PWD"'",
            "method":           "chacha20-ietf-poly1305",
            "fast_open":        true
        }' > 'ssserver.json'

        jq -n '
        {
            "server":           "'"$CRED_USR_SS_ADDR"'",
            "server_port":      '"$CRED_USR_SS_PORT"',
            "local_address":    "127.0.0.1",
            "local_port":       1080,
            "password":         "'"$CRED_USR_SS_PWD"'",
            "method":           "chacha20-ietf-poly1305",
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
ExecStart=/usr/local/bin/$([ "_$SS_IMPL" = '_-libev' ] && echo ss-server || echo ssserver) -c /etc/shadowsocks/ssserver.json
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
ExecStart=/usr/local/bin/$([ "_$SS_IMPL" = '_-libev' ] && echo ss-local || echo sslocal) -c /etc/shadowsocks/sslocal.json
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
        for i in hybla; do
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

        for i in hybla; do
            if modprobe -a "tcp_$i"; then
                echo "net.ipv4.tcp_allowed_congestion_control = $(sysctl -n net.ipv4.tcp_allowed_congestion_control) $i" >> "$SS_CONF"
            fi
        done
    )

    # ------------------------------------------------------------

    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    echo > "$INSTALL_ROOT/../fpm/post_install.sh" "
export SS_PORT='$CRED_USR_SS_PORT/tcp'

if which firewall-cmd >/dev/null && firewall-cmd --state; then
    if [ -f '/usr/lib/systemd/system/shadowsocks.service' ]; then
        firewall-cmd --permanent --delete-service=ss || true
        if firewall-cmd --permanent --new-service=ss; then
            firewall-cmd --permanent --service=ss --set-short='Shadowsocks'
            firewall-cmd --permanent --service=ss --set-description='Shadowsocks-libev is a lightweight secured SOCKS5 proxy for embedded devices and low-end boxes.'
            firewall-cmd --permanent --service=ss --add-port="\$SS_PORT"
        else
            $IS_CONTAINER
        fi
    else
        firewall-cmd --permanent --delete-service=ss || $IS_CONTAINER
    fi
    firewall-cmd --reload || $IS_CONTAINER
fi

for i in shadowsocks shadowsocks-client; do
    if [ -f "/usr/lib/systemd/system/\$i.service" ]; then
        systemctl enable "\$i"
        systemctl start "\$i" || $IS_CONTAINER
    else
        systemctl disable "\$i"
        systemctl stop "\$i" || $IS_CONTAINER
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
