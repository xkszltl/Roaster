#!/bin/bash

if [ $# -le 0 ]; then
    echo "Usage:"
    echo "    $0 <hostname...>"
    exit 1
fi

Domain='codingcafe.org'

for Host in $@; do
    if [ "$Host" = '@' ]; then
        FQDN="$Domain"
    else
        FQDN="$Host.$Domain"
    fi
    certbot delete          \
        --cert-name "$FQDN" \
        --non-interactive
    certbot certonly                            \
        --agree-tos                             \
        --preferred-challenges=dns              \
        --manual                                \
        --manual-auth-hook certbot-dnspod.sh    \
        --manual-cleanup-hook certbot-dnspod.sh \
        --manual-public-ip-logging-ok           \
        --non-interactive                       \
        --rsa-key-size 4096                     \
        -m xkszltl@gmail.com                    \
        -d "$FQDN"
done

