#!/bin/bash

set -e

# ================================================================
# Configuration
# ================================================================

[ "$ROOT_DIR" ] || export ROOT_DIR="$(dirname "$0")/.."
cd "$ROOT_DIR"
. "pkgs/env/cred.sh"

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

# Dnspod China
set +e
(
    set -e
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
        curl "$API/$Domain/records/TXT/$HOST"   \
            -H "Content-Type: application/json" \
            -H "$Token"                         \
            -sSLX PUT                           \
            -d "$(set -e;
                echo '[]'                                   \
                | jq -e ".[. | length] |= . + {}"           \
                | jq -e ".[. | length - 1].data |= \"\""    \
                | jq -e ".[. | length - 1].ttl  |= 600"     \
                | jq -Sce)"                     \
        | jq -Se '.'
    fi
    if [ ! "$CERTBOT_AUTH_OUTPUT" ]; then
        curl "$API/$Domain/records/TXT/$HOST"   \
            -H "Content-Type: application/json" \
            -H "$Token"                         \
            -sSLX PUT                           \
            -d "$(set -e;
                echo '[]'                                                   \
                | jq -e ".[. | length] |= . + {}"                           \
                | jq -e ".[. | length - 1].data |= \"$CERTBOT_VALIDATION\"" \
                | jq -e ".[. | length - 1].ttl  |= 600"                     \
                | jq -Sce)"                     \
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
