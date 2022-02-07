# ================================================================
# Install Fonts
# ================================================================

[ -e $STAGE/font ] && ( set -xe
    if [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ]; then
        # export HTTP_PROXY=proxy.codingcafe.org:8118
        [ "$HTTP_PROXY" ] && export HTTPS_PROXY="$HTTP_PROXY"
        [ "$HTTP_PROXY" ] && export http_proxy="$HTTP_PROXY"
        [ "$HTTPS_PROXY" ] && export https_proxy="$HTTPS_PROXY"
    fi

    export MSFONTS_URL='https://sourceforge.net/projects/mscorefonts2/files/rpms'
    export MSFONTS_VER=$(curl -sSL $MSFONTS_URL     \
        | sed -n 's/.*\(msttcore-fonts-installer-\([0-9]*\).\([0-9]*\)-\([0-9]*\).noarch.rpm\).*/\2 \3 \4 \1/p'     \
        | sort -n | tail -n1 | cut -d' ' -f4 -)

    echo "Found $MSFONTS_VER"

    # Install fc-cache before bypassing it.

    for attempt in $(seq "$RPM_MAX_ATTEMPT" -1 0); do
        [ $attempt -gt 0 ] || exit 1
        $RPM_INSTALL --setopt=strict=0  \
            fontconfig{,-*}             \
            && break
        echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
    done

    sudo mv -f /usr/bin/fc-cache{,.bak}
    sudo ln -sf /usr/bin/{true,fc-cache}

    for attempt in $(seq "$RPM_MAX_ATTEMPT" -1 0); do
        [ $attempt -gt 0 ] || exit 1
        $RPM_INSTALL --setopt=strict=0 *-fonts{,-*} \
        && $RPM_INSTALL $MSFONTS_URL/$MSFONTS_VER   \
        && break
        echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
    done

    sudo mv -f /usr/bin/fc-cache{.bak,}

    # ------------------------------------------------------------

    sudo fc-cache -fv

    sudo "$(which dnf >/dev/null 2>&1 && echo 'dnf' || echo 'yum')" autoremove -y
)
sudo rm -vf $STAGE/font
sync || true
