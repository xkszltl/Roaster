# ================================================================
# Account Configuration
# ================================================================

[ -e $STAGE/auth ] && ( set -xe
    cd
    mkdir -p ".ssh"
    chmod 700 "$_"
    cd "$_"
    rm -rvf id_{ecdsa,ed25519,rsa}{,.pub}
    parallel -j0 --line-buffer --bar 'bash -c '"'"'
        set -e
        export ALGO="$(sed '"'"'s/,.*//'"'"' <<< '"'"'{}'"'"')"
        export BITS="$(sed '"'"'s/.*,//'"'"' <<< '"'"'{}'"'"')"
        ssh-keygen -qN "" -f "id_$ALGO" -t "$ALGO" -b "$BITS"
    '"'" ::: 'ecdsa,521' 'ed25519,512' 'rsa,8192'
    echo 'Pre-generated SSH keys should only be used for demo since the private key is well-known.'
    cd "$SCRATCH"

    # ------------------------------------------------------------

    if [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ]; then
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel' | 'scientific')
            pushd '/etc/openldap'
            for i in 'BASE' 'URI' 'TLS_CACERT' 'TLS_REQCERT'; do :
                if [ "$(grep "^[[:space:]#]*$i[[:space:]]" 'ldap.conf' | wc -l)" -ne 1 ]; then
                    sed "s/^[[:space:]#]*$i[[:space:]].*//" 'ldap.conf' > "$SCRATCH/.ldap.conf"
                    sudo echo "# $i " >> "$SCRATCH/.ldap.conf"
                    sudo mv -f {"$SCRATCH/.",}'ldap.conf'
                fi
            done
            sudo cat 'ldap.conf'                                                                                        \
            | sed 's/^[[:space:]#]*\(BASE[[:space:]][[:space:]]*\).*/\1dc=codingcafe,dc=org/'                           \
            | sed 's/^[[:space:]#]*\(URI[[:space:]][[:space:]]*\).*/\1ldap:\/\/ldap.codingcafe.org/'                    \
            | sed 's/^[[:space:]#]*\(TLS_CACERT[[:space:]][[:space:]]*\).*/\1\/etc\/pki\/tls\/certs\/ca-bundle.crt/'    \
            | sed 's/^[[:space:]#]*\(TLS_REQCERT[[:space:]][[:space:]]*\).*/\1demand/'                                  \
            > "$SCRATCH/.ldap.conf"
            sudo mv -f {"$SCRATCH/.",}'ldap.conf'
            popd

            # May fail at the first time in unprivileged docker due to domainname change.
            for i in $($IS_CONTAINER && echo true) false; do :
                sudo authconfig                                                                     \
                    --enable{sssd{,auth},ldap{,auth,tls},locauthorize,cachecreds,mkhomedir}         \
                    --disable{cache,md5,nis,rfc2307bis}                                             \
                    --ldapserver=ldap://ldap.codingcafe.org                                         \
                    --ldapbasedn=dc=codingcafe,dc=org                                               \
                    --passalgo=sha512                                                               \
                    --smbsecurity=user                                                              \
                    --update                                                                        \
                || $i
            done

            sudo systemctl daemon-reload || $IS_CONTAINER
            for i in sssd; do :
                sudo systemctl enable $i
                sudo systemctl start $i || $IS_CONTAINER
            done
            ;;
        'debian' | 'linuxmint' | 'ubuntu')
            pushd '/etc/ldap'
            for i in 'BASE' 'URI' 'TLS_CACERT' 'TLS_REQCERT'; do :
                if [ "$(grep "^[[:space:]#]*$i[[:space:]]" 'ldap.conf' | wc -l)" -ne 1 ]; then
                    sed "s/^[[:space:]#]*$i[[:space:]].*//" 'ldap.conf' > "$SCRATCH/.ldap.conf"
                    sudo echo "# $i " >> "$SCRATCH/.ldap.conf"
                    sudo mv -f {"$SCRATCH/.",}'ldap.conf'
                fi
            done
            sudo cat 'ldap.conf'                                                                                        \
            | sed 's/^[[:space:]#]*\(BASE[[:space:]][[:space:]]*\).*/\1dc=codingcafe,dc=org/'                           \
            | sed 's/^[[:space:]#]*\(URI[[:space:]][[:space:]]*\).*/\1ldap:\/\/ldap.codingcafe.org/'                    \
            | sed 's/^[[:space:]#]*\(TLS_CACERT[[:space:]][[:space:]]*\).*/\1\/etc\/pki\/tls\/certs\/ca-bundle.crt/'    \
            | sed 's/^[[:space:]#]*\(TLS_REQCERT[[:space:]][[:space:]]*\).*/\1demand/'                                  \
            > "$SCRATCH/.ldap.conf"
            sudo mv -f {"$SCRATCH/.",}'ldap.conf'
            popd

            printf '\n# Automatically added by "%s".\n\nsession required pam_mkhomedir.so\n' "$0" | sudo tee -a '/etc/pam.d/common-session'

            cat << ____________EOF | sed 's/^                //' | sudo tee '/etc/sssd/sssd.conf'
                [sssd]

                config_file_version = 2
                domains = codingcafe.org

                [domain/codingcafe.org]

                auth_provider = ldap
                cache_credentials = True
                chpass_provider = ldap
                enumerate = True
                id_provider = ldap
                ldap_id_use_start_tls = True
                ldap_search_base = dc=codingcafe,dc=org
                ldap_sudo_full_refresh_interval = 3600
                ldap_sudo_search_base = ou=SUDOers,dc=codingcafe,dc=org
                ldap_sudo_smart_refresh_interval = 600
                ldap_uri = ldap://ldap.codingcafe.org
                sudo_provider = ldap
____________EOF
            sudo chmod 600 '/etc/sssd/sssd.conf'

            sudo systemctl daemon-reload || $IS_CONTAINER
            sudo systemctl restart sssd  || $IS_CONTAINER
            ;;
        *)
            echo "Unsupported distro \"DISTRO_ID\" for ldap configuration, skipped."
            ;;
        esac
    fi
    cd "$SCRATCH"

    # ------------------------------------------------------------

    git config --global core.editor         'vim'
    git config --global credential.helper   'store'
    git config --global pull.ff             'only'
    git config --global push.default        'simple'
    git config --global user.email          'xkszltl@gmail.com'
    git config --global user.name           'Roaster Project'
)
sudo rm -vf $STAGE/auth
sync "$STAGE" || true
