# ================================================================
# Install Fonts
# ================================================================

[ -e $STAGE/font ] && ( set -e
    for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
        $RPM_INSTALL *-fonts{,-*} --skip-broken && break
        echo "Retrying... $attempt chance(s) left."
        [ $attempt -gt 0 ] || exit 1
    done

    # ------------------------------------------------------------

    for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
        $RPM_INSTALL "https://downloads.sourceforge.net/project/mscorefonts2/rpms/$(
        curl -sSL https://sourceforge.net/projects/mscorefonts2/files/rpms/                                         \
            | sed -n 's/.*\(msttcore-fonts-installer-\([0-9]*\).\([0-9]*\)-\([0-9]*\).noarch.rpm\).*/\2 \3 \4 \1/p'     \
            | sort -n | tail -n1 | cut -d' ' -f4 -
        )" && break
        echo "Retrying... $attempt chance(s) left."
        [ $attempt -gt 0 ] || exit 1
    done

    fc-cache -fv

    yum autoremove -y
)
rm -rvf $STAGE/font
sync || true
