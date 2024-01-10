# ================================================================
# Git Repository Mirror Selection
# ================================================================

export GIT_MIRROR_GITHUB="1,https://github.com"
export GIT_MIRROR_CODINGCAFE="500,https://git.codingcafe.org/Mirrors"

# ----------------------------------------------------------------

(
    set -e

    . <(sed 's/^\(..*\)/export DISTRO_\1/' '/etc/os-release')

    missing_pkgs=''
    case "$DISTRO_ID" in
    'centos' | 'fedora' | 'rhel' | 'scientific')
        which bc     >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;bc"
        which column >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;util-linux"
        which dig    >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;bind-utils"
        which paste  >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;coreutils"
        which ping   >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;iputils"
        which sed    >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;sed"
        which xargs  >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;findutils"
        ;;
    'debian' | 'linuxmint' | "ubuntu")
        which bc     >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;bc"
        which column >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;bsdmainutils"
        which dig    >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;dnsutils"
        which paste  >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;coreutils"
        which ping   >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;iputils-ping"
        which sed    >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;sed"
        which xargs  >/dev/null 2>&1 || missing_pkgs="$missing_pkgs;findutils"
        ;;
    esac
    missing_pkgs="$(sed 's/;;*/;/g' <<< "$missing_pkgs" | sed 's/^;*//' | sed 's/;*$//')"

    if [ "$missing_pkgs" ]; then
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel' | 'scientific')
            sudo "$(which dnf >/dev/null 2>&1 && echo 'dnf' || echo 'yum')" makecache -y
            tr ';' ' ' <<< "$missing_pkgs" | sudo xargs "$(which dnf >/dev/null 2>&1 && echo 'dnf' || echo 'yum')" install -y
            ;;
        'debian' | 'linuxmint' | "ubuntu")
            sudo DEBIAN_FRONTEND=noninteractive apt-get -o 'DPkg::Lock::Timeout=3600' update
            tr ';' ' ' <<< "$missing_pkgs" | sudo DEBIAN_FRONTEND=noninteractive xargs apt-get -o 'DPkg::Lock::Timeout=3600' install -y
            ;;
        esac
    fi
)

echo '----------------------------------------------------------------'
echo '               Measure link quality to git mirrors              '
echo '----------------------------------------------------------------'
export LINK_QUALITY="$(
    export PING_ROUND=$(sudo ping -nfc 10 localhost > /dev/null && echo '-fc100' || echo '-i0.2 -c10')
    for i in $(env | sed -n 's/^GIT_MIRROR_[^=]*=//p'); do :
        price="$(cut -d',' -f1 <<< "$i,")"
        url="$(cut -d',' -f2 <<< "$i,")"
        fqdn="$(sed 's/.*:\/\///' <<<"$url" | sed 's/\/.*//' | sed 's/.*@//' | sed 's/:.*//')"
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

[ "$GIT_MIRROR" ] || GIT_MIRROR="$(head -n1 <<< "$LINK_QUALITY" | tail -n1 | xargs -n1 | tail -n+2 | head -n1)"
echo '----------------------------------------------------------------'
echo "| GIT_MIRROR | $GIT_MIRROR"
echo '----------------------------------------------------------------'

. <(env | sed -n 's/^\(GIT_MIRROR_[^=]*=\)[^,]*,/export \1/p')
