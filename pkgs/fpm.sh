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

    # Dependency public_suffix has minimum ruby version requirements.
    if [ "_$(ruby --version | cut -d' ' -f2 | cut -d. -f-2 | sed 's/^/2\.0 /' | tr ' ' '\n' | sort -V | head -n1)" != "_2.0" ]; then
        sudo gem install 'public_suffix:<1.5'
    elif [ "_$(ruby --version | cut -d' ' -f2 | cut -d. -f-2 | sed 's/^/2\.1 /' | tr ' ' '\n' | sort -V | head -n1)" != "_2.1" ]; then
        sudo gem install 'public_suffix:<3'
    elif [ "_$(ruby --version | cut -d' ' -f2 | cut -d. -f-2 | sed 's/^/2\.3 /' | tr ' ' '\n' | sort -V | head -n1)" != "_2.3" ]; then
        sudo gem install 'public_suffix:<4'
    elif [ "_$(ruby --version | cut -d' ' -f2 | cut -d. -f-2 | sed 's/^/2\.6 /' | tr ' ' '\n' | sort -V | head -n1)" != "_2.6" ]; then
        sudo gem install 'public_suffix:<5'
    fi

    (
        set -e

        # Known issues:
        # - Dependency dotenv 3.0.0 (released in Feb 2024) requires ruby 3.0.
        case "$DISTRO_ID-$DISTRO_VERSION_ID" in
        'centos-7' | 'rhel-7' | 'scientific-7.'*)
            set +e
            scl enable rh-ruby26 'gem build fpm.gemspec'
            sudo scl enable rh-ruby26 'gem install dotenv -v "< 3"'
            # Document of childprocess failed to build with rh-ruby26.
            sudo scl enable rh-ruby26 'gem install --no-document ./fpm-*.gem'
            set -e
            sudo gem install dotenv -v '< 3'
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
        'ubuntu-20.04')
            gem build fpm.gemspec
            sudo gem install dotenv -v '< 3'
            sudo gem install ./fpm-*.gem
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
sync "$STAGE" || true
