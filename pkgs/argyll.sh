# ================================================================
# Compile Argyll
# ================================================================

[ -e $STAGE/argyll ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    mkdir -p argyll
    cd argyll
    axel -an20 -o 'argyll_src.zip' 'https://www.argyllcms.com/Argyll_V2.3.0_src.zip'
    axel -an20 -o 'argyll.tgz' 'https://www.argyllcms.com/Argyll_V2.3.0_linux_x86_64_bin.tgz'

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    mkdir -p "$INSTALL_ABS/src"
    unzip -o 'argyll_src.zip' -d "$INSTALL_ABS/src/"
    rm -rf "$INSTALL_ABS/src/argyll"
    mv -f "$INSTALL_ABS/src/"{Argyll_*,argyll}
    rm -rf 'arrgyll_src.zip'

    mkdir -p "$INSTALL_ABS/share/argyll"
    tar --strip-components=1 -C "$INSTALL_ABS/share/argyll" -xvf 'argyll.tgz'
    rm -rf 'arrgyll.tgz'
    mkdir -p "$INSTALL_ABS/bin"
    pushd "$INSTALL_ABS/bin"
    find '../share/argyll/bin' -maxdepth 1 -executable -type f | xargs -n1 ln -sf
    popd

    DESC='2.3.0-0-0000000' "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/argyll
)
sudo rm -vf $STAGE/argyll
sync || true
