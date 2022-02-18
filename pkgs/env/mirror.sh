# ================================================================
# Git Repository Mirror Selection
# ================================================================

export GIT_MIRROR_GITHUB="1,https://github.com"
export GIT_MIRROR_CODINGCAFE="500,https://git.codingcafe.org/Mirrors"

# ----------------------------------------------------------------

case "$DISTRO_ID" in
'centos' | 'fedora' | 'rhel' | 'scientific')
    which bc     > /dev/null 2> /dev/null || sudo "$(which dnf >/dev/null 2>&1 && echo 'dnf' || echo 'yum')" install -y bc
    which column > /dev/null 2> /dev/null || sudo "$(which dnf >/dev/null 2>&1 && echo 'dnf' || echo 'yum')" install -y util-linux
    which dig    > /dev/null 2> /dev/null || sudo "$(which dnf >/dev/null 2>&1 && echo 'dnf' || echo 'yum')" install -y bind-utils
    which paste  > /dev/null 2> /dev/null || sudo "$(which dnf >/dev/null 2>&1 && echo 'dnf' || echo 'yum')" install -y coreutils
    which ping   > /dev/null 2> /dev/null || sudo "$(which dnf >/dev/null 2>&1 && echo 'dnf' || echo 'yum')" install -y iputils
    which sed    > /dev/null 2> /dev/null || sudo "$(which dnf >/dev/null 2>&1 && echo 'dnf' || echo 'yum')" install -y sed
    which xargs  > /dev/null 2> /dev/null || sudo "$(which dnf >/dev/null 2>&1 && echo 'dnf' || echo 'yum')" install -y findutils
    ;;
'debian' | 'linuxmint' | "ubuntu")
    which bc     > /dev/null 2> /dev/null || sudo apt-get install -y bc
    which column > /dev/null 2> /dev/null || sudo apt-get install -y bsdmainutils
    which dig    > /dev/null 2> /dev/null || sudo apt-get install -y dnsutils
    which paste  > /dev/null 2> /dev/null || sudo apt-get install -y coreutils
    which ping   > /dev/null 2> /dev/null || sudo apt-get install -y iputils-ping
    which sed    > /dev/null 2> /dev/null || sudo apt-get install -y sed
    which xargs  > /dev/null 2> /dev/null || sudo apt-get install -y findutils
    ;;
esac

echo '----------------------------------------------------------------'
echo '               Measure link quality to git mirrors              '
echo '----------------------------------------------------------------'
export LINK_QUALITY="$(
    export PING_ROUND=$(sudo ping -nfc 10 localhost > /dev/null && echo '-fc100' || echo '-i0.2 -c10')
    for i in $(env | sed -n 's/^GIT_MIRROR_[^=]*=//p'); do :
        price="$(cut -d',' -f1 <<< "$i,")"
        url="$(cut -d',' -f2 <<< "$i,")"
        fqdn="$(sed 's/.*:\/\///' <<<"$url" | sed 's/\/.*//')"
        sudo ping -W 1 -n $PING_ROUND "$fqdn"                                                       \
        | sed -n '/ms$/p'                                                                           \
        | sed 's/.*[^0-9]\([0-9]*\)%.*[^0-9\.]\([0-9\.]*\).*ms/\1 \2/'                              \
        | sed 's/.*ewma.*\/\([0-9\.]*\).*/\1/'                                                      \
        | xargs                                                                                     \
        | sed "s/\([0-9\.][0-9\.]*\).*[[:space:]]\([0-9\.][0-9\.]*\).*/\2\*\(\1\*10+1\)\*$price/"   \
        | sed 's/^$/10\^20/'                                                                        \
        | bc
        printf '%s %s\n' "$url" "$(! which dig >/dev/null 2>&1 || dig '+noall' '+short' -t A "$fqdn" | grep '[^\.]$' | paste -sd' ' -)"
    done | paste - - | sort -n | column -t
)"

sed 's/^/| /' <<< "$LINK_QUALITY"

[ "$GIT_MIRROR" ] || GIT_MIRROR="$(head -n1 <<< "$LINK_QUALITY" | tail -n1 | xargs -n1 | head -n2 | tail -n1)"
echo '----------------------------------------------------------------'
echo "| GIT_MIRROR | $GIT_MIRROR"
echo '----------------------------------------------------------------'

. <(env | sed -n 's/^\(GIT_MIRROR_[^=]*=\)[^,]*,/export \1/p')
