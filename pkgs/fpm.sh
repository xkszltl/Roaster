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
        case "$DISTRO_ID-$DISTRO_VERSION_ID" in
        'centos-7' | 'rhel-7' | 'scientific-7.'*)
            scl enable rh-ruby26 'gem build fpm.gemspec'
            # Document of childprocess failed to build with rh-ruby26.
            sudo scl enable rh-ruby26 'gem install --no-document ./fpm-*.gem'
            # Dependency ffi-1.13 requires ruby 2.3 while stock version is 2.0.
            sudo gem install 'ffi:<1.13'
            # fpm 1.12.0 has git dependency requiring ruby>=2.3.
            sudo gem install --no-document ./fpm-*.gem || true
            # Export SCL installation.
            for cmd in '/usr/local/bin/fpm'; do
                cat << EOF | sed 's/^[[:space:]]*//' | sudo tee "$cmd"
                    #!/bin/bash

                    . scl_source enable rh-ruby26
                    "\$(basename "\$0")" "\$@"
                    exit "\$?"
EOF
                sudo chmod +x '/usr/local/bin/fpm'
            done
            ;;
        *)
            gem build fpm.gemspec
            sudo gem install ./fpm-*.gem
            ;;
        esac
    )
    fpm --version

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/fpm
)
sudo rm -vf $STAGE/fpm
sync || true
