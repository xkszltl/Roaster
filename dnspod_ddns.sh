#!/bin/bash

set -e

# ================================================================
# Configuration
# ================================================================

[ "$ROOT_DIR" ] || export ROOT_DIR="$(dirname "$0")"
cd "$ROOT_DIR"
. 'pkgs/env/cred.sh'

TokenCloudflareAccount="$CRED_USR_CLOUDFLARE_KEY"
TokenCloudflare="$CRED_USR_CLOUDFLARE_SECRET"

TokenDnspodCN="$CRED_USR_DNSPOD_CN_KEY,$CRED_USR_DNSPOD_CN_SECRET"
TokenDnspodIntl="$CRED_USR_DNSPOD_INTL_KEY,$CRED_USR_DNSPOD_INTL_SECRET"

TokenDNSCOMKey="$CRED_USR_DNSCOM_KEY"
TokenDNSCOMSecret="$CRED_USR_DNSCOM_SECRET"

TokenGoDaddy="$CRED_USR_GODADDY_KEY:$CRED_USR_GODADDY_SECRET"

# ----------------------------------------------------------------

Domain='codingcafe.org'

# ================================================================
# Main
# ================================================================

LastDir="$(mktemp -d)"
cd "$LastDir"

for cmd in curl grep jq snmpwalk sed xargs; do
    which "$cmd" >/dev/null
done

while true; do
    echo '========================================'
    for Rec in def {snmp,httpbin,ifcfg,ipify,jsonip}.c{t,u}cc; do
        IP='0.0.0.0'
        # IP=`curl -s ns1.dnspod.net:6666 $Interface`

        if grep -q '^snmp\.' <<< "$Rec"; then
            grep -q '\.ctcc$' <<< "$Rec" && Interface='Dialer10'
            grep -q '\.cucc$' <<< "$Rec" && Interface='Dialer20'
            IP=$(snmpwalk -v3 -u monitor -x AES -m IP-MIB 10.0.0.1 ipAdEntIfIndex | sed -n 's/.*\.\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\).*[[:space:]]'"$(snmpwalk -v3 -u monitor -x AES -m IF-MIB 10.0.0.1 ifName | sed -n 's/.*\.\([0-9]*\).*[[:space:]]'$Interface'$/\1/p')"'$/\1/p') || echo 'ERROR: Failed to retrieve SNMP data for "'"$Rec"'"'
        elif grep -q '^httpbin\.' <<< "$Rec"; then
            IP=$(curl -sSL 'https://httpbin.org/ip' --interface "$(sed -n 's/^.*\.//p' <<<$Rec)" | jq -er '.origin') || echo 'ERROR: Failed to retrieve IP for "'"$Rec"'"'
        elif grep -q '^ifcfg\.' <<< "$Rec"; then
            IP=$(curl -sSL 'https://ifcfg.net/' --interface "$(sed -n 's/^.*\.//p' <<<$Rec)") || echo 'ERROR: Failed to retrieve IP for "'"$Rec"'"'
        elif grep -q '^ipify\.' <<< "$Rec"; then
            IP=$(curl -sSL 'https://api.ipify.org?format=json' --interface "$(sed -n 's/^.*\.//p' <<<$Rec)" | jq -er '.ip') || echo 'ERROR: Failed to retrieve IP for "'"$Rec"'"'
        elif grep -q '^jsonip\.' <<< "$Rec"; then
            IP=$(curl -sSL 'https://jsonip.com' --interface "$(sed -n 's/^.*\.//p' <<<$Rec)" | jq -er '.ip') || echo 'ERROR: Failed to retrieve IP for "'"$Rec"'"'
        else
            IP=$(curl -sSL 'https://jsonip.com' | jq -er '.ip') || echo 'ERROR: Failed to retrieve IP for "'"$Rec"'"'
        fi

        IP="$(xargs <<< "$IP" | sed -n 's/^[[:space:]]*\([^[:space:]]*\).*$/\1/p' | head -n 1)"
        [ "$IP" ] || IP='0.0.0.0'
        if ! grep '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' <<< "$IP"; then
            echo "Failed to detect IP for \"$Rec.$Domain\". Skipped."
            continue
        fi

        # Cloudflare
        set +e
        (
            set -e
            set +x
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
                curl "$API/zones/$ZoneID/dns_records?name=$Rec.$Domain&type=A"  \
                    -H "Content-Type: application/json"                         \
                    -H "$Token"                                                 \
                    -sSLX GET                                                   \
                | jq -Se 'select(.success)'                                     \
                | jq -r '.result[0].id'                                         \
                | sed 's/^null$//')"
            if [ ! "$RecID" ]; then
                echo "[Cloudflare] Create $Rec.$Domain ($IP)"
                RecID="$(set -e
                    curl "$API/zones/$ZoneID/dns_records"   \
                        -H "Content-Type: application/json" \
                        -H "$Token"                         \
                        -sSLX POST                          \
                        -d "$(set -e
                            echo '{}'                       \
                            | jq -e ".content = \"$IP\""    \
                            | jq -e ".name = \"$Rec\""      \
                            | jq -e ".ttl = 120"            \
                            | jq -e ".type = \"A\""         \
                            | jq -Sce)"                     \
                    | jq -Se 'select(.success)'             \
                    | jq -er '.result.id')"
            fi
            [ "$RecID" ]
            Record="$(curl "$API/zones/$ZoneID/dns_records/$RecID"  \
                    -H "Content-Type: application/json"             \
                    -H "$Token"                                     \
                    -sSLX GET                                       \
                | jq -Se 'select(.success)')"
            if [ ! -e "$Rec" ]; then
                jq -er '.result.content' <<< "$Record" > "$Rec"
                echo "[Cloudflare] Set $Rec.$Domain to $(cat "$Rec")"
            fi
            LastIP="$(cat "$Rec")"
            if [ "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$IP" | bc)" -eq "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$LastIP" | bc)" ]; then
                echo "[Cloudflare] Nothing change for $Rec.$Domain ($IP)"
            else
                echo "[Cloudflare] Update $Rec.$Domain ($LastIP -> $IP)"
                Res="$(set -e
                    curl "$API/zones/$ZoneID/dns_records/$RecID"    \
                        -H "Content-Type: application/json"         \
                        -H "$Token"                                 \
                        -sSLX PUT                                   \
                        -d "$(set -e
                            echo '{}'                               \
                            | jq -e ".content = \"$IP\""            \
                            | jq -e ".name = \"$Rec\""              \
                            | jq -e ".ttl = 120"                    \
                            | jq -e ".type = \"A\""                 \
                            | jq -Sce)"                             \
                    | jq -Se 'select(.success)')"
                [ "$Res" ]
                rm -rf "$Rec"
            fi
        )
        [ "$?" -eq 0 ] || echo "ERROR: Failed to update [Cloudflare]"
        set -e

        # Dnspod China
        set +e
        (
            set -e
            set +x
            [ "$TokenDnspodCN" ]
            API="https://dnsapi.cn"
            Token="login_token=$TokenDnspodCN"
            mkdir -p "Dnspod/CN"
            cd "$_"
            DomainID="$(curl "$API/Domain.List" \
                    -sSLX POST                  \
                    -d "$Token"                 \
                    -d "format=json"            \
                | jq -r '.domains[] | select(.name=="'"$Domain"'") | .id')"
            Records="$(curl "$API/Record.List"  \
                    -sSLX POST                  \
                    -d "$Token"                 \
                    -d "format=json"            \
                    -d "domain=$Domain"         \
                | jq '.records[]')"
            [ "$Records" ]
            RecID="$(jq -r 'select(.name=="'"$Rec"'") | .id' <<< "$Records")"
            [ "$RecID" ]
            if [ ! -e "$Rec" ]; then
                jq -r 'select(.name=="'"$Rec"'") | .value' <<< "$Records" > "$Rec"
                echo "[Dnspod-CN] Set $Rec.$Domain to $(cat "$Rec")"
            fi
            LastIP="$(cat "$Rec")"
            if [ "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$IP" | bc)" -eq "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$LastIP" | bc)" ]; then
                echo "[Dnspod-CN] Nothing change for $Rec.$Domain ($IP)"
            else
                echo "[Dnspod-CN] Update $Rec.$Domain ($LastIP -> $IP)"
                curl "$API/Record.Ddns"         \
                    -sSLX POST                  \
                    -d "$Token"                 \
                    -d "domain=$Domain"         \
                    -d "format=json"            \
                    -d "record_id=$RecID"       \
                    -d "record_line=默认"       \
                    -d "sub_domain=$Rec"        \
                    -d "value=$IP"              \
                | jq '.'

                rm -rf "$Rec"
            fi
        )
        [ "$?" -eq 0 ] || echo "ERROR: Failed to update [Dnspod-CN]"
        set -e

        # Dnspod Intl
        set +e
        (
            set -e
            set +x
            [ "$TokenDnspodIntl" ]
            API="https://api.dnspod.com"
            Token="user_token=$TokenDnspodIntl"
            mkdir -p "Dnspod/Intl"
            cd "$_"
            DomainID="$(curl "$API/Domain.List" \
                    -sSLX POST                  \
                    -d "$Token"                 \
                    -d "format=json"            \
                | jq -r '.domains[] | select(.name=="'"$Domain"'") | .id')"
            Records="$(curl "$API/Record.List"  \
                    -sSLX POST                  \
                    -d "$Token"                 \
                    -d "format=json"            \
                    -d "domain=$Domain"         \
                | jq '.records[]')"
            [ "$Records" ]
            RecID="$(jq -r 'select(.name=="'"$Rec"'") | .id' <<< "$Records")"
            [ "$RecID" ]
            if [ ! -e "$Rec" ]; then
                jq -r 'select(.name=="'"$Rec"'") | .value' <<< "$Records" > "$Rec"
                echo "[Dnspod-Intl] Set $Rec.$Domain to $(cat "$Rec")"
            fi
            LastIP="$(cat "$Rec")"
            if [ "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$IP" | bc)" -eq "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$LastIP" | bc)" ]; then
                echo "[Dnspod-Intl] Nothing change for $Rec.$Domain ($IP)"
            else
                echo "[Dnspod-Intl] Update $Rec.$Domain ($LastIP -> $IP)"
                curl "$API/Record.Ddns"         \
                    -sSLX POST                  \
                    -d "$Token"                 \
                    -d "domain=$Domain"         \
                    -d "format=json"            \
                    -d "record_id=$RecID"       \
                    -d "record_line=default"    \
                    -d "sub_domain=$Rec"        \
                    -d "value=$IP"              \
                | jq '.'
                rm -rf "$Rec"
            fi
        )
        [ "$?" -eq 0 ] || echo "ERROR: Failed to update [Dnspod-Intl]"
        set -e

        # DNS.com
        set +e
        (
            set -e
            set +x
            [ "$TokenDNSCOMKey"    ]
            [ "$TokenDNSCOMSecret" ]
            API="https://www.dns.com/api"
            Token="apiKey=$TokenDNSCOMKey"
            mkdir -p "DNS.com"
            cd "$_"
            # curl "$API/domain/list/"                            \
            #     -sSLX POST                                      \
            #     -H 'Content-type:text/html;charset=utf-8'       \
            #     -d "$Token"                                     \
            #     -d "hash="$(md5 <<< "$Token$TokenDNSCOMSecret") \
            # | jq '.'
        )
        [ "$?" -eq 0 ] || echo "ERROR: Failed to update [DNS.com]"
        set -e

        # GoDaddy
        set +e
        (
            set -e
            set +x
            [ "$TokenGoDaddy" ]
            API="https://api.godaddy.com/v1/domains"
            Token="Authorization: sso-key $TokenGoDaddy"
            mkdir -p "GoDaddy"
            cd "$_"
            Records="$(curl "$API/$Domain/records/A/$Rec"   \
                    -H "$Token"                             \
                    -sSLX GET                               \
                | jq -Se '.')"
            [ "_$(jq -er 'type' <<< "$Records")" = '_array' ]
            Record="$(jq -Se '.data="0.0.0.0"' <<< '{}')"
            [ "$(jq -e 'length' <<< "$Records")" -le 0 ] || Record="$(jq -Se '.[0]' <<< "$Records")"
            [ "$Record" ]
            if [ ! -e "$Rec" ]; then
                jq -r '.data' <<< "$Record" > "$Rec"
                echo "[GoDaddy] Set $Rec.$Domain to $(cat "$Rec")"
            fi
            LastIP="$(cat "$Rec")"
            if [ "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$IP" | bc)" -eq "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$LastIP" | bc)" ]; then
                echo "[GoDaddy] Nothing change for $Rec.$Domain ($IP)"
            else
                echo "[GoDaddy] Update $Rec.$Domain ($LastIP -> $IP)"
                curl "$API/$Domain/records/A/$Rec"      \
                    -H "Content-Type: application/json" \
                    -H "$Token"                         \
                    -sSLX PUT                           \
                    -d "$(set -e;
                        echo '[]'                                   \
                        | jq -e ".[. | length] |= . + {}"           \
                        | jq -e ".[. | length - 1].data |= \"$IP\"" \
                        | jq -e ".[. | length - 1].ttl  |= 600"     \
                        | jq -Sce)"                     \
                | jq -Se '.'
                rm -rf "$Rec"
            fi
        )
        [ "$?" -eq 0 ] || echo "ERROR: Failed to update [GoDaddy]"
        set -e
    done
    sleep 10
done

cd
rm -rf "$LastDir"
