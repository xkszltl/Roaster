#!/bin/bash

############################################################
# Default Credentials
#     These values are invalid.
#     They are only place holders.
############################################################

export CRED_DEF_SS_ADDR="example.org"
export CRED_DEF_SS_PORT='8388'
export CRED_DEF_SS_PWD="Default_random_password_@!$(sha1sum <<< "$RANDOM$RANDOM" | sed 's/[[:space:]].*//')"

export CRED_DEF_DNSPOD_CN_LE_KEY='12345'
export CRED_DEF_DNSPOD_CN_LE_SECRET='1234567890abcdef0123456789abcdef'

export CRED_DEF_DNSPOD_CN_KEY='12345'
export CRED_DEF_DNSPOD_CN_SECRET='1234567890abcdef0123456789abcdef'

export CRED_DEF_DNSPOD_INTL_KEY='730060'
export CRED_DEF_DNSPOD_INTL_SECRET='e1a8a$f14dc5dcbafd83680b3d2a553c4d553d'

export CRED_DEF_DNSCOM_KEY='123456789abcdef0123456789abcdef0'
export CRED_DEF_DNSCOM_SECRET='123456789abcdef0123456789abcdef0'

############################################################
# Load User-defined Credentials
############################################################

cred_usr="$(readlink -m "$(dirname "$0")/../../cred/env-cred-usr.sh")"
if [ -x "$cred_usr" ]; then
    echo "Load user-defined credential from \"$cred_usr\"."
    . "$cred_usr"
fi

for i in $(env | grep '^CRED_DEF_'); do
    def_env="$(cut -d'=' -f1 <<< "$i=")"
    usr_env="$(sed -n 's/^CRED_DEF_/CRED_USR_/p' <<< "$def_env")"
    if [ ! "$def_env" ] || [ ! "$usr_env" ]; then
        echo "Cannot detect credential env properly:"
        echo "    def_env=$def_env"
        echo "    usr_env=$usr_env"
        exit 1
    fi
    eval "[ \"\$$usr_env\" ]" || eval export "$usr_env=\"\$$def_env\""
done
