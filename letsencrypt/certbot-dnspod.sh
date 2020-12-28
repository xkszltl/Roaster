#!/bin/bash

set -e

# ================================================================
# Configuration
# ================================================================

[ "$ROOT_DIR" ] || export ROOT_DIR="$(dirname "$0")/.."
cd "$ROOT_DIR"
. "pkgs/env/cred.sh"

TokenCloudflareAccount="$CRED_USR_CLOUDFLARE_LE_KEY"
TokenCloudflare="$CRED_USR_CLOUDFLARE_LE_SECRET"

TokenDnspodCN="$CRED_USR_DNSPOD_CN_LE_KEY,$CRED_USR_DNSPOD_CN_LE_SECRET"
TokenGoDaddy="$CRED_USR_GODADDY_LE_KEY:$CRED_USR_GODADDY_LE_SECRET"

# ----------------------------------------------------------------

MaxRetries=5
Propagation=5

Domain='codingcafe.org'

if [ "_$(sed 's/.*\.\([^\.]*\.[^\.]*\)$/\1/' <<< "$CERTBOT_DOMAIN")" != "_$Domain" ]; then
    echo "ERROR: Domain provided by certbot ($CERTBOT_DOMAIN) does not match the pre-defined value."
    exit 1
fi

# ================================================================
# Main
#   - Use $CERTBOT_AUTH_OUTPUT to distinguish between main/cleanup runs.
# ================================================================

HOST="$(sed 's/\.[^\.]*\.[^\.]*$//' <<< "_acme-challenge.$CERTBOT_DOMAIN")"

# Cloudflare
set +e
(
    set -e
    [ "$TokenCloudflare"        ]
    [ "$TokenCloudflareAccount" ]
    API="https://api.cloudflare.com/client/v4"
    Token="Authorization: Bearer $TokenCloudflare"
    mkdir -p "Cloudflare"
    cd "$_"
    ZoneID="$(set -e
        curl "$API/zones?account.id=$TokenCloudflareAccount&name=$Domain"   \
            -H "Content-Type: application/json"                             \
            -H "$Token"                                                     \
            -sSLX GET                                                       \
        | jq -Se 'select(.success)'                                         \
        | jq -er '.result[0].id')"
    [ "$ZoneID" ]
    RecID="$(set -e
        curl "$API/zones/$ZoneID/dns_records?name=$HOST.$Domain&type=TXT"   \
            -H "Content-Type: application/json"                             \
            -H "$Token"                                                     \
            -sSLX GET                                                       \
        | jq -Se 'select(.success)'                                         \
        | jq -r '.result[0].id'                                             \
        | sed 's/^null$//')"
    [ "$RecID" ] || [ ! "$CERTBOT_AUTH_OUTPUT" ]
    if [ "$RecID" ]; then
        curl "$API/zones/$ZoneID/dns_records/$RecID"    \
            -H "Content-Type: application/json"         \
            -H "$Token"                                 \
            -sSLX DELETE                                \
        | jq -Se 'select(.success)'                     \
        | jq -er '.result.id'                           \
        > /dev/null
    fi
    if [ ! "$CERTBOT_AUTH_OUTPUT" ]; then
        curl "$API/zones/$ZoneID/dns_records"                   \
            -H "Content-Type: application/json"                 \
            -H "$Token"                                         \
            -sSLX POST                                          \
            -d "$(set -e
                echo '{}'                                       \
                | jq -e ".content = \"$CERTBOT_VALIDATION\""    \
                | jq -e ".name = \"$HOST\""                     \
                | jq -e ".ttl = 120"                            \
                | jq -e ".type = \"TXT\""                       \
                | jq -Sce)"                                     \
        | jq -Se 'select(.success)'                             \
        | jq -er '.result.id'                                   \
        > /dev/null
    fi
)
[ "$?" -eq 0 ] || echo "ERROR: Failed to update [Cloudflare]"
set -e

# Dnspod China
set +e
(
    set -e
    [ "$TokenDnspodCN" ]
    API="https://dnsapi.cn"
    Token="login_token=$TokenDnspodCN"
    RecID="$(curl "$API/Record.List"    \
            -sSLX POST                  \
            -d "$Token"                 \
            -d "domain=$Domain"         \
            -d "format=json"            \
        | jq -r '.records[] | select(.name=="'"$HOST"'") | .id')"
    [ "$RecID" ] || [ ! "$CERTBOT_AUTH_OUTPUT" ]
    if [ "$RecID" ]; then
        curl "$API/Record.Remove"       \
            -sSLX POST                  \
            -d "$Token"                 \
            -d "domain=$Domain"         \
            -d "format=json"            \
            -d "record_id=$RecID"       \
        | jq '.'
    fi
    if [ ! "$CERTBOT_AUTH_OUTPUT" ]; then
        curl "$API/Record.Create"           \
            -sSLX POST                      \
            -d "$Token"                     \
            -d "domain=$Domain"             \
            -d "format=json"                \
            -d "record_id=$RecID"           \
            -d "record_line=默认"           \
            -d "record_type=TXT"            \
            -d "sub_domain=$HOST"           \
            -d "value=$CERTBOT_VALIDATION"  \
        | jq '.'
    fi
)
[ "$?" -eq 0 ] || echo "ERROR: Failed to update [Dnspod-CN]"
set -e

# GoDaddy
set +e
(
    set -e
    [ "$TokenGoDaddy" ]
    API="https://api.godaddy.com/v1/domains"
    Token="Authorization: sso-key $TokenGoDaddy"
    RecCnt="$(set -e
        curl "$API/$Domain/records/TXT/$HOST"   \
            -H "Content-Type: application/json" \
            -H "$Token"                         \
            -sSLX GET                           \
        | jq -Se 'length')"
    [ "$RecCnt" -gt 0 ] || [ ! "$CERTBOT_AUTH_OUTPUT" ]
    if [ "$RecCnt" -gt 0 ]; then
        curl "$API/$Domain/records/TXT/$HOST"               \
            -H "Content-Type: application/json"             \
            -H "$Token"                                     \
            -sSLX PUT                                       \
            -d "$(set -e;
                echo '[]'                                   \
                | jq -e ".[. | length] |= . + {}"           \
                | jq -e ".[. | length - 1].data |= \"\""    \
                | jq -e ".[. | length - 1].ttl  |= 600"     \
                | jq -Sce)"                                 \
        | jq -Se '.'
    fi
    if [ ! "$CERTBOT_AUTH_OUTPUT" ]; then
        curl "$API/$Domain/records/TXT/$HOST"                               \
            -H "Content-Type: application/json"                             \
            -H "$Token"                                                     \
            -sSLX PUT                                                       \
            -d "$(set -e;
                echo '[]'                                                   \
                | jq -e ".[. | length] |= . + {}"                           \
                | jq -e ".[. | length - 1].data |= \"$CERTBOT_VALIDATION\"" \
                | jq -e ".[. | length - 1].ttl  |= 600"                     \
                | jq -Sce)"                                                 \
        | jq -Se '.'
    fi
)
[ "$?" -eq 0 ] || echo "ERROR: Failed to update [GoDaddy]"
set -e

# ================================================================
# Wait for propagation
# ================================================================

if [ ! "$CERTBOT_AUTH_OUTPUT" ]; then
    sleep "$Propagation"
    for remain in $(seq "$MaxRetries" -1 0); do
        dig -t TXT "$HOST.$Domain" +noall +answer | sed -n '/^[^;]/p' | grep 'TXT' && break
        echo "Waiting for the validation record...$remain retries remaining"
        sleep "$(expr "$MaxRetries" - "$remain" + 1)";
    done
fi
