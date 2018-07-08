#!/bin/bash

set -e

# ================================================================
# Configuration
# ================================================================

TokenDnspodCN='12345,1234567890abcdef0123456789abcdef'

# ----------------------------------------------------------------

Domain=codingcafe.org

# ================================================================
# Main
# ================================================================

# Dnspod China
( set -e
    API="https://dnsapi.cn"
    Token="login_token=$TokenDnspodCN"
    HOST="$(sed 's/\.[^\.]*\.[^\.]*$//' <<< "_acme-challenge.$CERTBOT_DOMAIN")"
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
            -d "record_line=默认"            \
            -d "record_type=TXT"            \
            -d "sub_domain=$HOST"           \
            -d "value=CERTBOT_VALIDATION"   \
        | jq '.'
    fi
) || echo "ERROR: Failed to update [Dnspod-CN]"
