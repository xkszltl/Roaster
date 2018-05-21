# ================================================================
# Compile FPM
# ================================================================

[ -e $STAGE/fpm ] && ( set -xe
    cd $SCRATCH
    
    # ------------------------------------------------------------

    until git clone $GIT_MIRROR/jordansissel/fpm.git; do echo 'Retrying'; done
    cd fpm
    # git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    # ------------------------------------------------------------

    (
        set +x
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
