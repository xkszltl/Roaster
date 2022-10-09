#!/bin/bash

set -e

if [ "$#" -le 0 ]; then
    printf "Usage:\n    %s <hostname...>\n" "$0" >&2
    exit 1
fi

[ "$Domain" ] || Domain='codingcafe.org'

for Host in "$@"; do
    [ "$Host" = '@' ] && FQDN="$Domain" || FQDN="$Host.$Domain"
    certbot delete          \
        --cert-name "$FQDN" \
        --non-interactive   \
    || true
    certbot certonly                            \
        --agree-tos                             \
        --preferred-challenges=dns              \
        --manual                                \
        --manual-auth-hook certbot-dnspod.sh    \
        --manual-cleanup-hook certbot-dnspod.sh \
        --manual-public-ip-logging-ok           \
        --non-interactive                       \
        --rsa-key-size 4096                     \
        -m 'xkszltl@gmail.com'                  \
        -d "$FQDN"
done

