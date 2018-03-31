# ================================================================
# Git Repository Mirror Selection
# ================================================================

export GIT_MIRROR_GITHUB=https://github.com
export GIT_MIRROR_CODINGCAFE=https://git.codingcafe.org/Mirrors

# ----------------------------------------------------------------

which bc > /dev/null 2> /dev/null || sudo yum install --skip-broken -y bc
which sed > /dev/null 2> /dev/null || sudo yum install --skip-broken -y sed
which paste > /dev/null 2> /dev/null || sudo yum install --skip-broken -y coreutils
which xargs > /dev/null 2> /dev/null || sudo yum install --skip-broken -y findutils

sudo ping -nfc 10 localhost > /dev/null                                     \
&& echo '----------------------------------------------------------------'  \
&& echo '               Measure link quality to git mirrors              '  \
&& echo '----------------------------------------------------------------'  \
&& env | sed -n 's/^GIT_MIRROR_[^=]*=/| /p'                                 \
&& export GIT_MIRROR=$(
    export PING_ROUND=$(sudo ping -nfc 10 localhost > /dev/null && echo '-fc100' || echo '-i0.2 -c10')
    for i in $(env | sed -n 's/^GIT_MIRROR_[^=]*=//p'); do :
        ping -n $PING_ROUND $(sed 's/.*:\/\///' <<<"$i" | sed 's/\/.*//')                   \
        | sed -n '/ms$/p'                                                                   \
        | sed 's/.*[^0-9]\([0-9]*\)%.*[^0-9\.]\([0-9\.]*\).*ms/\1 \2/'                      \
        | sed 's/.*ewma.*\/\([0-9\.]*\).*/\1/'                                              \
        | xargs                                                                             \
        | sed 's/\([0-9\.][0-9\.]*\).*[[:space:]]\([0-9\.][0-9\.]*\).*/\2\*\(\1\*10+1\)/'   \
        | bc
        echo "$i"
    done | paste - - | sort -n | head -n1 | xargs -n1 | tail -n1
)
echo '----------------------------------------------------------------'
echo "| GIT_MIRROR | $GIT_MIRROR"
echo '----------------------------------------------------------------'
