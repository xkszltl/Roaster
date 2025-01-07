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

[ ! "$CRED_USR_DNSPOD_CN_KEY" ] || [ ! "$CRED_USR_DNSPOD_CN_SECRET" ] || TokenDnspodCN="$CRED_USR_DNSPOD_CN_KEY,$CRED_USR_DNSPOD_CN_SECRET"
[ ! "$CRED_USR_DNSPOD_INTL_KEY" ] || [ ! "$CRED_USR_DNSPOD_INTL_SECRET" ] || TokenDnspodIntl="$CRED_USR_DNSPOD_INTL_KEY,$CRED_USR_DNSPOD_INTL_SECRET"

TokenDNSCOMKey="$CRED_USR_DNSCOM_KEY"
TokenDNSCOMSecret="$CRED_USR_DNSCOM_SECRET"

[ ! "$CRED_USR_GODADDY_KEY" ] || [ ! "$CRED_USR_GODADDY_SECRET" ] || TokenGoDaddy="$CRED_USR_GODADDY_KEY:$CRED_USR_GODADDY_SECRET"

# ----------------------------------------------------------------

[ "$Domain"  ] || Domain='codingcafe.org'
[ "$Gateway" ] || Gateway='10.0.0.1'

# ================================================================
# Main
# ================================================================

LastDir="$(mktemp -d)"
trap "trap - SIGTERM; rm -rf '$LastDir'; kill -- -'$$'" SIGINT SIGTERM EXIT
cd "$LastDir"

for cmd in curl grep jq snmpwalk sed xargs; do
    ! which "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "%s".\033[0m\n' "$cmd" >&2
    exit 1
done

# Check for SNMP MIB.
snmptranslate -m IP-MIB 'RFC1213-MIB::ipAdEntIfIndex' >/dev/null
snmptranslate -m IF-MIB 'IF-MIB::ifName' >/dev/null

while true; do
    printf '\033[36m[INFO] ========================================\033[0m\n' >&2
    for Rec in def {snmp,cf,httpbin,ipify,jsonip}.c{t,u}cc; do
        IP='0.0.0.0'
        # IP=`curl -s ns1.dnspod.net:6666 $Interface`

        case "$Rec" in
        'snmp.'*)
            IP="$(set -e
                    snmpwalk -v3 -u monitor -x AES -m IP-MIB "$Gateway" 'RFC1213-MIB::ipAdEntIfIndex'   \
                    | sed -n 's/.*\.\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\).*[[:space:]]'"$(set -e
                            snmpwalk -v3 -u monitor -x AES -m IF-MIB "$Gateway" 'IF-MIB::ifName'        \
                            | sed -n 's/.*\.\([0-9]*\).*[[:space:]]'"$(set -e
                                    printf '%s' "$Rec"                                                  \
                                    | sed 's/.*\.ctcc$/#Dialer10/'                                      \
                                    | sed 's/.*\.cucc$/#Dialer20/'                                      \
                                    | sed -n 's/^#//p'                                                  \
                                    | sed 's/\([\\\/\.\-]\)/\\\1/'
                                )"'$/\1/p'
                        )"'$/\1/p'
                )"
            ;;
        'cf.'*)
            IP="$(set -e
                    printf '%s' "$Rec"                          \
                    | sed -n 's/^.*\.//p'                       \
                    | xargs -rI{} curl --interface {} -sSL      \
                        'https://cloudflare.com/cdn-cgi/trace'  \
                    | grep '^[[:space:]]*ip[[:space:]]*='       \
                    | cut -d= -f2-
                )"
            ;;
        'httpbin.'*)
            IP="$(set -e
                    printf '%s' "$Rec"                      \
                    | sed -n 's/^.*\.//p'                   \
                    | xargs -rI{} curl --interface {} -sSL  \
                        'https://httpbin.org/ip'            \
                    | jq -er '.origin'
                )"
            ;;
        'ipify.'*)
            IP="$(set -e
                    printf '%s' "$Rec"                          \
                    | sed -n 's/^.*\.//p'                       \
                    | xargs -rI{} curl --interface {} -sSL      \
                        'https://api4.ipify.org?format=json'    \
                    | jq -er '.ip'
                )"
            ;;
        'jsonip.'*)
            IP="$(set -e
                    printf '%s' "$Rec"                      \
                    | sed -n 's/^.*\.//p'                   \
                    | xargs -rI{} curl --interface {} -sSL  \
                        'https://ipv4.jsonip.com'           \
                    | jq -er '.ip'
                )"
            ;;
        *)
            IP="$(curl -sSL 'https://jsonip.com' | jq -er '.ip')"
            ;;
        esac
        IP="$(printf '%s' "$IP" | tr '[:space:]' '\n' | grep . | head -n1)"
        if [ ! "$IP" ]; then
            printf '\033[33m[WARNING] Failed to retrieve IP for "%s".\033[0m\n' "$Rec" >&2
            IP='0.0.0.0'
        fi
        if ! printf '%s' "$IP" | grep -q '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$'; then
            printf '\033[33m[WARNING] Failed to detect IP for "%s". Skipped.\033[0m\n' "$Rec.$Domain" >&2
            continue
        fi

        # Cloudflare
        if [ "$TokenCloudflare" ] && [ "$TokenCloudflareAccount" ]; then
            set +e
            (
                set -e +x
                API="https://api.cloudflare.com/client/v4"
                Token="Authorization: Bearer $TokenCloudflare"
                mkdir -p "Cloudflare"
                cd "$_"
                ZoneID="$(set -e
                        curl "$API/zones?account.id=$TokenCloudflareAccount&name=$Domain"   \
                            --connect-timeout 10                                            \
                            --retry 10                                                      \
                            --retry-delay 1                                                 \
                            --retry-max-time 120                                            \
                            -4                                                              \
                            -H "Content-Type: application/json"                             \
                            -H "$Token"                                                     \
                            -sSLX GET                                                       \
                        | jq -Se 'select(.success)'                                         \
                        | jq -er '.result[0].id'
                    )"
                [ "$ZoneID" ]
                RecID="$(set -e
                        curl "$API/zones/$ZoneID/dns_records?name=$Rec.$Domain&type=A"  \
                            --connect-timeout 10                                        \
                            --retry 10                                                  \
                            --retry-delay 1                                             \
                            --retry-max-time 120                                        \
                            -4                                                          \
                            -H "Content-Type: application/json"                         \
                            -H "$Token"                                                 \
                            -sSLX GET                                                   \
                        | jq -Se 'select(.success)'                                     \
                        | jq -r '.result[0].id'                                         \
                        | sed 's/^null$//'
                    )"
                if [ ! "$RecID" ] && [ ! 'Init' ]; then
                    printf '\033[36m[INFO] [Cloudflare] Create "%s" ("%s").\033[0m\n' "$Rec.$Domain" "$IP" >&2
                    RecID="$(set -e
                            curl "$API/zones/$ZoneID/dns_records"       \
                                --connect-timeout 10                    \
                                -4                                      \
                                -H "Content-Type: application/json"     \
                                -H "$Token"                             \
                                -sSLX POST                              \
                                -d "$(set -e
                                        echo '{}'                       \
                                        | jq -e ".content = \"$IP\""    \
                                        | jq -e ".name = \"$Rec\""      \
                                        | jq -e ".ttl = 120"            \
                                        | jq -e ".type = \"A\""         \
                                        | jq -Sce
                                    )"                                  \
                            | jq -Se 'select(.success)'                 \
                            | jq -er '.result.id'
                        )"
                fi
                [ "$RecID" ]
                Record="$(set -e
                        curl "$API/zones/$ZoneID/dns_records/$RecID"        \
                            --connect-timeout 10                            \
                            --retry 10                                      \
                            --retry-delay 1                                 \
                            --retry-max-time 120                            \
                            -4                                              \
                            -H "Content-Type: application/json"             \
                            -H "$Token"                                     \
                            -sSLX GET                                       \
                        | jq -Se 'select(.success)'
                    )"
                [ "$Record" ]
                if [ ! -e "$Rec" ]; then
                    printf "%s" "$Record" | jq -er '.result.content' > "$Rec"
                    printf '\033[36m[INFO] [Cloudflare] Set "%s" to "%s".\033[0m\n' "$Rec.$Domain" "$(cat "$Rec")" >&2
                fi
                LastIP="$(cat "$Rec" | grep '[^[:space:]]')"
                [ "$LastIP" ]
                if [ "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$IP" | bc)" -eq "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$LastIP" | bc)" ]; then
                    printf '\033[36m[INFO] [Cloudflare] Nothing changed for "%s" ("%s").\033[0m\n' "$Rec.$Domain" "$IP" >&2
                else
                    printf '\033[36m[INFO] [Cloudflare] Update "%s" ("%s" -> "%s").\033[0m\n' "$Rec.$Domain" "$LastIP" "$IP" >&2
                    Res="$(set -e
                            curl "$API/zones/$ZoneID/dns_records/$RecID"    \
                                --connect-timeout 10                        \
                                --retry 10                                  \
                                --retry-delay 1                             \
                                --retry-max-time 120                        \
                                -4                                          \
                                -H "Content-Type: application/json"         \
                                -H "$Token"                                 \
                                -sSLX PUT                                   \
                                -d "$(set -e
                                        echo '{}'                           \
                                        | jq -e ".content = \"$IP\""        \
                                        | jq -e ".name = \"$Rec\""          \
                                        | jq -e ".ttl = 120"                \
                                        | jq -e ".type = \"A\""             \
                                        | jq -Sce
                                    )"                                      \
                            | jq -Se 'select(.success)'
                        )"
                    [ "$Res" ]
                    rm -rf "$Rec"
                fi
            )
            [ "$?" -eq 0 ] || printf '\033[33m[WARNING] Failed to update "%s" on Cloudflare.\033[0m\n' "$Rec" >&2
            set -e
        fi

        # Dnspod China
        if [ "$TokenDnspodCN" ]; then
            set +e
            (
                set -e +x
                API="https://dnsapi.cn"
                Token="login_token=$TokenDnspodCN"
                mkdir -p "Dnspod/CN"
                cd "$_"
                DomainID="$(set -e
                        curl "$API/Domain.List"     \
                            -sSLX POST              \
                            -d "$Token"             \
                            -d "format=json"        \
                        | jq -r '.domains[] | select(.name=="'"$Domain"'") | .id'
                    )"
                Records="$(set -e
                        curl "$API/Record.List"     \
                            -sSLX POST              \
                            -d "$Token"             \
                            -d "format=json"        \
                            -d "domain=$Domain"     \
                        | jq '.records[]'
                    )"
                [ "$Records" ]
                RecID="$(printf '%s' "$Records" | jq -r 'select(.name=="'"$Rec"'") | .id')"
                [ "$RecID" ]
                if [ ! -e "$Rec" ]; then
                    printf "%s" "$Records" | jq -r 'select(.name=="'"$Rec"'") | .value' > "$Rec"
                    printf '\033[36m[INFO] [Dnspod-CN] Set "%s" to "%s".\033[0m\n' "$Rec.$Domain" "$(cat "$Rec")" >&2
                fi
                LastIP="$(cat "$Rec" | grep '[^[:space:]]')"
                [ "$LastIP" ]
                if [ "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$IP" | bc)" -eq "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$LastIP" | bc)" ]; then
                    printf '\033[36m[INFO] [Dnspod-CN] Nothing changed for "%s" ("%s").\033[0m\n' "$Rec.$Domain" "$IP" >&2
                else
                    printf '\033[36m[INFO] [Dnspod-CN] Update "%s" ("%s" -> "%s").\033[0m\n' "$Rec.$Domain" "$LastIP" "$IP" >&2
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
            [ "$?" -eq 0 ] || printf '\033[33m[WARNING] Failed to update "%s" on Dnspod-CN.\033[0m\n' "$Rec" >&2
            set -e
        fi

        # Dnspod Intl
        if [ "$TokenDnspodIntl" ]; then
            set +e
            (
                set -e +x
                API="https://api.dnspod.com"
                Token="user_token=$TokenDnspodIntl"
                mkdir -p "Dnspod/Intl"
                cd "$_"
                DomainID="$(set -e
                        curl "$API/Domain.List" \
                            -sSLX POST          \
                            -d "$Token"         \
                            -d "format=json"    \
                        | jq -r '.domains[] | select(.name=="'"$Domain"'") | .id'
                    )"
                Records="$(set -e
                        curl "$API/Record.List" \
                            -sSLX POST          \
                            -d "$Token"         \
                            -d "format=json"    \
                            -d "domain=$Domain" \
                        | jq '.records[]'
                    )"
                [ "$Records" ]
                RecID="$(printf '%s' "$Records" | jq -r 'select(.name=="'"$Rec"'") | .id')"
                [ "$RecID" ]
                if [ ! -e "$Rec" ]; then
                    printf "%s" "$Records" | jq -r 'select(.name=="'"$Rec"'") | .value' > "$Rec"
                    printf '\033[36m[INFO] [Dnspod-Intl] Set "%s" to "%s".\033[0m\n' "$Rec.$Domain" "$(cat "$Rec")" >&2
                fi
                LastIP="$(cat "$Rec" | grep '[^[:space:]]')"
                [ "$LastIP" ]
                if [ "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$IP" | bc)" -eq "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$LastIP" | bc)" ]; then
                    printf '\033[36m[INFO] [Dnspod-Intl] Nothing changed for "%s" ("%s").\033[0m\n' "$Rec.$Domain" "$IP" >&2
                else
                    printf '\033[36m[INFO] [Dnspod-Intl] Update "%s" ("%s" -> "%s").\033[0m\n' "$Rec.$Domain" "$LastIP" "$IP" >&2
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
            [ "$?" -eq 0 ] || printf '\033[33m[WARNING] Failed to update "%s" on Dnspod-Intl.\033[0m\n' "$Rec" >&2
            set -e
        fi

        # DNS.com
        if [ "$TokenDNSCOMKey" ] && [ "$TokenDNSCOMSecret" ]; then
            set +e
            (
                set -e +x
                [ "$TokenDNSCOMKey"    ]
                [ "$TokenDNSCOMSecret" ]
                API="https://www.dns.com/api"
                Token="apiKey=$TokenDNSCOMKey"
                mkdir -p "DNS.com"
                cd "$_"
                # curl "$API/domain/list/"                                          \
                #     -sSLX POST                                                    \
                #     -H 'Content-type:text/html;charset=utf-8'                     \
                #     -d "$Token"                                                   \
                #     -d "hash=$(printf '%s' "$Token$TokenDNSCOMSecret" | md5)"     \
                # | jq '.'
            )
            [ "$?" -eq 0 ] || printf '\033[33m[WARNING] Failed to update "%s" on DNS.com.\033[0m\n' "$Rec" >&2
            set -e
        fi

        # GoDaddy
        if [ "$TokenGoDaddy" ]; then
            set +e
            (
                set -e +x
                API="https://api.godaddy.com/v1/domains"
                Token="Authorization: sso-key $TokenGoDaddy"
                mkdir -p "GoDaddy"
                cd "$_"
                Records="$(curl "$API/$Domain/records/A/$Rec"   \
                        -H "$Token"                             \
                        -sSLX GET                               \
                    | jq -Se '.')"
                [ "_$(printf "%s" "$Records" | jq -er 'type')" = '_array' ]
                Record="$(echo '{}' | jq -Se '.data="0.0.0.0"')"
                [ "$(printf "%s" "$Records" | jq -e 'length')" -le 0 ] || Record="$(printf '%s' "$Records" | jq -Se '.[0]')"
                [ "$Record" ]
                if [ ! -e "$Rec" ]; then
                    printf "%s" "$Record" | jq -r '.data' > "$Rec"
                    printf '\033[36m[INFO] [GoDaddy] Set "%s" to "%s".\033[0m\n' "$Rec.$Domain" "$(cat "$Rec")" >&2
                fi
                LastIP="$(cat "$Rec" | grep '[^[:space:]]')"
                [ "$LastIP" ]
                if [ "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$IP" | bc)" -eq "$(sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<< "$LastIP" | bc)" ]; then
                    printf '\033[36m[INFO] [GoDaddy] Nothing changed for "%s" ("%s").\033[0m\n' "$Rec.$Domain" "$IP" >&2
                else
                    printf '\033[36m[INFO] [GoDaddy] Update "%s" ("%s" -> "%s").\033[0m\n' "$Rec.$Domain" "$LastIP" "$IP" >&2
                    curl "$API/$Domain/records/A/$Rec"      \
                        -H "Content-Type: application/json" \
                        -H "$Token"                         \
                        -sSLX PUT                           \
                        -d "$(set -e
                                echo '[]'                                   \
                                | jq -e ".[. | length] |= . + {}"           \
                                | jq -e ".[. | length - 1].data |= \"$IP\"" \
                                | jq -e ".[. | length - 1].ttl  |= 600"     \
                                | jq -Sce
                            )"                              \
                    | jq -Se '.'
                    rm -rf "$Rec"
                fi
            )
            [ "$?" -eq 0 ] || printf '\033[33m[WARNING] Failed to update "%s" on GoDaddy.\033[0m\n' "$Rec" >&2
            set -e
        fi
    done
    sleep 10
done

cd
rm -rf "$LastDir"
trap - SIGTERM SIGINT EXIT
