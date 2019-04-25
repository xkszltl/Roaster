# ================================================================
# Git Repository Mirror Selection
# ================================================================

export GIT_MIRROR_GITHUB="1,https://github.com"
export GIT_MIRROR_CODINGCAFE="10000,https://git.codingcafe.org/Mirrors"

# ----------------------------------------------------------------

which bc > /dev/null 2> /dev/null || sudo yum install --skip-broken -y bc
which sed > /dev/null 2> /dev/null || sudo yum install --skip-broken -y sed
which paste > /dev/null 2> /dev/null || sudo yum install --skip-broken -y coreutils
which xargs > /dev/null 2> /dev/null || sudo yum install --skip-broken -y findutils

echo '----------------------------------------------------------------'
echo '               Measure link quality to git mirrors              '
echo '----------------------------------------------------------------'
export LINK_QUALITY="$(
    export PING_ROUND=$(sudo ping -nfc 10 localhost > /dev/null && echo '-fc100' || echo '-i0.2 -c10')
    for i in $(env | sed -n 's/^GIT_MIRROR_[^=]*=//p'); do :
        price="$(cut -d',' -f1 <<< "$i,")"
        url="$(cut -d',' -f2 <<< "$i,")"
        sudo ping -W 1 -n $PING_ROUND $(sed 's/.*:\/\///' <<<"$i" | sed 's/\/.*//')                 \
        | sed -n '/ms$/p'                                                                           \
        | sed 's/.*[^0-9]\([0-9]*\)%.*[^0-9\.]\([0-9\.]*\).*ms/\1 \2/'                              \
        | sed 's/.*ewma.*\/\([0-9\.]*\).*/\1/'                                                      \
        | xargs                                                                                     \
        | sed "s/\([0-9\.][0-9\.]*\).*[[:space:]]\([0-9\.][0-9\.]*\).*/\2\*\(\1\*10+1\)\*$price/"   \
        | sed 's/^$/10\^20/'                                                                        \
        | bc
        echo "$url"
    done | paste - - | sort -n | column -t
)"

sed 's/^/| /' <<< "$LINK_QUALITY"

[ "$GIT_MIRROR" ] || GIT_MIRROR="$(head -n1 <<< "$LINK_QUALITY" | xargs -n1 | tail -n1)"
echo '----------------------------------------------------------------'
echo "| GIT_MIRROR | $GIT_MIRROR"
echo '----------------------------------------------------------------'

. <(env | sed -n 's/^\(GIT_MIRROR_[^=]*=\)[^,]*,/export \1/p')
