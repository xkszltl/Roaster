# ================================================================
# Compile FPM
# ================================================================

[ -e $STAGE/fpm ] && ( set -xe
    cd $SCRATCH
    
    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" jordansissel/fpm,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd fpm

    # ------------------------------------------------------------

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            scl enable rh-ruby26 'gem build fpm.gemspec'
            # Document of childprocess failed to build with rh-ruby26.
            sudo scl enable rh-ruby26 'gem install --no-document ./fpm-*.gem'
            ;;
        *)
            gem build fpm.gemspec
            sudo gem install ./fpm-*.gem
            ;;
        esac
    )

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/fpm
)
sudo rm -vf $STAGE/fpm
sync || true
