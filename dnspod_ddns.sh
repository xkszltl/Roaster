#!/bin/bash

set -e

# ================================================================
# Configuration
# ================================================================

TokenDnspodCN='12345,1234567890abcdef0123456789abcdef'
TokenDnspodIntl='730060,e1a8a$f14dc5dcbafd83680b3d2a553c4d553d'

TokenDNSCOMKey='123456789abcdef0123456789abcdef0'
TokenDNSCOMSecret='123456789abcdef0123456789abcdef0'

# ----------------------------------------------------------------

Domain=codingcafe.org

# ================================================================
# Main
# ================================================================

LastDir=$(mktemp -d)
cd "$LastDir"

while true; do
    echo '========================================'
    for Rec in def {snmp,ifcfg}.c{t,u}cc; do
        # IP=`curl -s ns1.dnspod.net:6666 $Interface`
        if grep -q '^snmp\.' <<< "$Rec"; then
            grep -q '\.ctcc$' <<< "$Rec" && Interface='Dialer10'
            grep -q '\.cucc$' <<< "$Rec" && Interface='Dialer20'
            IP=$(snmpwalk -v3 -u monitor -x AES -m IP-MIB 10.0.0.1 ipAdEntIfIndex | sed -n 's/.*\.\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\).*[[:space:]]'"$(snmpwalk -v3 -u monitor -x AES -m IF-MIB 10.0.0.1 ifName | sed -n 's/.*\.\([0-9]*\).*[[:space:]]'$Interface'$/\1/p')"'$/\1/p') || echo 'ERROR: Failed to retrieve SNMP data for "'"$Rec"'"'
        elif grep -q '^ifcfg\.' <<< "$Rec"; then
            IP=$(curl -sSL https://ifcfg.net/ --interface "$(sed 's/^......//' <<<$Rec)") || echo 'ERROR: Failed to retrieve IP for "'"$Rec"'"'
        else
            IP=$(curl -sSL https://ifcfg.net/) || echo 'ERROR: Failed to retrieve IP for "'"$Rec"'"'
        fi;

        IP=$(xargs <<< "$IP" | sed -n 's/^[[:space:]]*\([^[:space:]]*\).*$/\1/p' | head -n 1);
        [ $IP ] || IP='0.0.0.0'

        # Dnspod China
        ( set -e
            set +x
            API="https://dnsapi.cn"
            Token="login_token=$TokenDnspodCN"
            mkdir -p "Dnspod/CN"
            cd "$_"
            DomainID=$(curl "$API/Domain.List"  \
                    -sSLX POST                  \
                    -d "$Token"                 \
                    -d "format=json"            \
                | jq -r '.domains[] | select(.name=="'"$Domain"'") | .id')
            Records=$(curl "$API/Record.List"   \
                    -sSLX POST                  \
                    -d "$Token"                 \
                    -d "format=json"            \
                    -d "domain=$Domain"         \
                | jq '.records[]')
            [ "$Records" ]
            RecID=$(jq -r 'select(.name=="'"$Rec"'") | .id' <<< "$Records")
            [ "$RecID" ]
            if [ ! -e "$Rec" ]; then
                jq -r 'select(.name=="'"$Rec"'") | .value' <<< "$Records" > "$Rec"
                echo "[Dnspod-CN] Set $Rec.$Domain to "`cat "$Rec"`
            fi
            LastIP=`cat "$Rec"`
            if [ `sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<<$IP | bc` -eq `sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<<$LastIP | bc` ]; then
                echo "[Dnspod-CN] Nothing change for $Rec.$Domain ($IP)"
            else
                echo "[Dnspod-CN] Update $Rec.$Domain ($LastIP -> $IP)"
                curl "$API/Record.Ddns"         \
                    -sSLX POST                  \
                    -d "$Token"                 \
                    -d "domain=$Domain"         \
                    -d "format=json"            \
                    -d "record_id=$RecID"       \
                    -d "record_line=默认"        \
                    -d "sub_domain=$Rec"        \
                    -d "value=$IP"              \
                | jq '.'

                rm -rf "$Rec"
            fi
        ) || echo "ERROR: Failed to update [Dnspod-CN]"

        # Dnspod Intl
        ( set -e
            set +x
            API="https://api.dnspod.com"
            Token="user_token=$TokenDnspodIntl"
            mkdir -p "Dnspod/Intl"
            cd "$_"
            DomainID=$(curl "$API/Domain.List"  \
                    -sSLX POST                  \
                    -d "$Token"                 \
                    -d "format=json"            \
                | jq -r '.domains[] | select(.name=="'"$Domain"'") | .id')
            Records=$(curl "$API/Record.List"   \
                    -sSLX POST                  \
                    -d "$Token"                 \
                    -d "format=json"            \
                    -d "domain=$Domain"         \
                | jq '.records[]')
            [ "$Records" ]
            RecID=$(jq -r 'select(.name=="'"$Rec"'") | .id' <<< "$Records")
            [ "$RecID" ]
            if [ ! -e "$Rec" ]; then
                jq -r 'select(.name=="'"$Rec"'") | .value' <<< "$Records" > "$Rec"
                echo "[Dnspod-Intl] Set $Rec.$Domain to "`cat "$Rec"`
            fi
            LastIP=`cat "$Rec"`
            if [ `sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<<$IP | bc` -eq `sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1\*2\^24\+\2\*2\^16\+\3\*2\^8\+\4/' <<<$LastIP | bc` ]; then
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
        ) || echo "ERROR: Failed to update [Dnspod-Intl]"

        # DNS.com
        ( set -e
            set +x
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
        ) || echo "ERROR: Failed to update [DNS.com]"
    done
    sleep 10
done

cd
rm -rf "$LastDir"
