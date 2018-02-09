# ================================================================
# Install Fonts
# ================================================================

[ -e $STAGE/font ] && ( set -e
    export MSFONTS_URL='https://sourceforge.net/projects/mscorefonts2/files/rpms'
    export MSFONTS_VER=$(curl -sSL $MSFONTS_URL     \
        | sed -n 's/.*\(msttcore-fonts-installer-\([0-9]*\).\([0-9]*\)-\([0-9]*\).noarch.rpm\).*/\2 \3 \4 \1/p'     \
        | sort -n | tail -n1 | cut -d' ' -f4 -)

    echo "Found $MSFONTS_VER"

    for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
        $RPM_INSTALL --skip-broken      \
            *-fonts{,-*}                \
            $MSFONTS_URL/$MSFONTS_VER   \
            && break
        echo "Retrying... $attempt chance(s) left."
        [ $attempt -gt 0 ] || exit 1
    done

    # ------------------------------------------------------------

    fc-cache -fv

    yum autoremove -y
)
rm -rvf $STAGE/font
sync || true
