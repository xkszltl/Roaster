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
        set +xe
        . scl_source enable rh-ruby25
        set -xe

        gem build fpm.gemspec
        sudo gem install ./fpm-*.gem
    )

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/fpm
)
sudo rm -vf $STAGE/fpm
sync || true
