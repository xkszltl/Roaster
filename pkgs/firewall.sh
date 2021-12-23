# ================================================================
# Setup Firewall Rules
# ================================================================

[ -e $STAGE/firewall ] && ( set -xe
    cd $SCRATCH

    if ! sudo firewall-cmd --state; then
        sudo systemctl enable firewalld || $IS_CONTAINER
        sudo systemctl --no-pager status firewalld || sudo systemctl start firewalld || $IS_CONTAINER
    fi

    sudo firewall-cmd --permanent --delete-service=afp || true
    if sudo firewall-cmd --permanent --new-service=afp; then
        sudo firewall-cmd --permanent --service=afp --set-short='Apple Filing Protocol'
        sudo firewall-cmd --permanent --service=afp --set-description='The Apple Filing Protocol (AFP), formerly AppleTalk Filing Protocol, is a proprietary network protocol, and part of the Apple File Service (AFS), that offers file services for macOS and the classic Mac OS.'
        sudo firewall-cmd --permanent --service=afp --add-port=548/{tcp,udp}
    else
        $IS_CONTAINER
    fi
    sudo firewall-cmd --reload || $IS_CONTAINER

    sudo firewall-cmd --permanent --delete-service=rdp || true
    if sudo firewall-cmd --permanent --new-service=rdp; then
        sudo firewall-cmd --permanent --service=rdp --set-short='Remote Desktop Protocol'
        sudo firewall-cmd --permanent --service=rdp --set-description='RDP is based on, and is an extension of, the T-120 family of protocol standards.'
        sudo firewall-cmd --permanent --service=rdp --add-port=3389/tcp
    else
        $IS_CONTAINER
    fi
    sudo firewall-cmd --reload || $IS_CONTAINER

    sudo firewall-cmd --list-all || $IS_CONTAINER
)
sudo rm -vf $STAGE/firewall
sync || true
