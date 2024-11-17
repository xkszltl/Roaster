#!/bin/bash

set -e

for cmd in curl git git-lfs grep jq parallel sed xargs; do
    ! which "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "%s".\033[0m\n' "$cmd" >&2
    exit 1
done

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

cd "$(dirname "$0")"

date || true

# export HTTP_PROXY=proxy.codingcafe.org:8118
[ ! "$HTTP_PROXY"  ] || export HTTPS_PROXY="$HTTP_PROXY"
[ ! "$HTTP_PROXY"  ] || export http_proxy="$HTTP_PROXY"
[ ! "$HTTPS_PROXY" ] || export https_proxy="$HTTPS_PROXY"

# Recommend to use group access token with "owner" role and "api" scope.
if [ "$GITLAB_CRED" ]; then
    printf '\033[33m[WARNING] $GITLAB_CRED should not be provided as env var for security reasons.\033[0m\n' >&2
else
    GITLAB_CRED="$(
        set -e +x
        ROOT_DIR="$(pwd)" . "pkgs/env/cred.sh" >&2
        printf '%s' "$CRED_USR_GITLAB_MIRROR_KEY"
    )"
fi

[ "$DST" ] || DST='git@git.codingcafe.org:Mirrors/'
# Append path separator if missing.
DST="$(printf '%s' "$DST" | sed 's/^\([^:@\\\/][^:@\\\/]*@[^:@\\\/][^:@\\\/]*\):*$/\1:/' | sed 's/\([^:\/]\)\/*$/\1\//')"

[ "$GITLAB_API" ] || GITLAB_API="https://git.codingcafe.org/api"
# Drop trailing path separator.
GITLAB_API="$(printf '%s' "$GITLAB_API" | sed 's/\/*$//')"

https_url="$(printf '%s' "$DST" | sed 's/^[^:@\\\/][^:@\\\/]*@\([^:@\\\/][^:@\\\/]*\):/https:\/\/\1\//' | sed 's/\/*$//')"

[ "$STAGE_DIR" ] || STAGE_DIR='/var/mirrors'
mkdir -p "$STAGE_DIR"

log="$(mktemp -t git-mirror-XXXXXXXX.log)"
! grep '[[:space:]]' <<< "$log" >/dev/null
trap "trap - SIGTERM && rm -f $log && kill -- -$$" SIGINT SIGTERM EXIT

# Concurrency restricted by GitHub.
./mirror-list.sh                                                    \
| grep $([ "$#" -gt 0 ] && printf ' -e%s' '^$' $@ || printf '.')    \
| grep .                                                            \
| parallel --bar --group --shuf -d '\n' -j 10 -q bash -c '
    set -e

    args="{}  "
    [ "$(printf "%s\n" "$args" | xargs -n1 | wc -l)" -ne 3 ] && exit 0
    cd "'"$STAGE_DIR"'"
    src_site="$(cut -d" " -f1 <<< "$args")"
    src_dir="$(cut -d" " -f3 <<< "$args")"
    src="$src_site$src_dir.git"
    dst_domain="$(cut -d" " -f2 <<< "$args" | sed "s/^\/*//" | sed "s/\/*$//" | sed "s/\(..*\)/\1\//")"
    dst_site="'"$DST"'$dst_domain"
    dst_dir="$src_dir"
    dst="$dst_site$dst_dir.git"
    local="$(pwd)/$dst_domain/$dst_dir.git"

    grep -v "^__" <<< "$src_dir" >/dev/null || exit 0

    printf "\033[36m[INFO] Mirror to \"$dst_dir\"\033[0m\n" >&2

    mkdir -p "$(dirname "$local")"
    cd "$(dirname "$local")"
    set +e
    ! which scl 2>&1 > /dev/null || . scl_source enable rh-git227 || . scl_source enable rh-git218
    set -e
    [ -d "$local" ] || git clone --mirror "$dst" "$local" 2>&1 || git clone --mirror "$src" "$local" 2>&1
    cd "$local"
    git remote set-url origin "$dst" 2>&1
    git config remote.origin.mirror true
    git fetch origin 2>&1 || true
    git fetch --tags origin 2>&1 || true
    if git lfs ls-files | head -n1 | grep . >/dev/null || git lfs ls-files --deleted | head -n1 | grep . >/dev/null || git lfs ls-files -a | head -n1 | grep . >/dev/null; then
        git lfs fetch --all origin 2>&1 || true
    fi
    git remote set-url origin "$src" 2>&1
    # git fetch --prune origin 2>&1
    git fetch --prune --tags origin 2>&1
    git gc --auto 2>&1

    # GitLab-specific:
    # - Create groups/subgroups if missing.
    if '"$([ "$GITLAB_CRED" ] && printf 'true' || printf 'false')"'; then
        for lvl in $(
            set -e
            curl -sSLX GET                                                  \
                -H "Authorization: Bearer '"$GITLAB_CRED"'"                 \
                "'"$GITLAB_API"'/v4/groups/$(
                        set -e
                        printf "Mirrors%s/%s" "$dst_domain" "$dst_dir"      \
                        | sed "s/\/[^\/][^\/]*$//"                          \
                        | sed "s/ /%20/g"                                   \
                        | sed "s/\//%2F/g"
                    )"                                                      \
            | jq -er .id                                                    \
            | grep "^[0-9][0-9]*$" >/dev/null                               \
            || printf "Mirrors%s/%s" "$dst_domain" "$dst_dir"               \
            | tr "/" "\n"                                                   \
            | grep .                                                        \
            | wc -l                                                         \
            | xargs -r expr -1 +                                            \
            | xargs -r seq 2
        ); do
            printf "\033[36m[INFO] Create group level %d.\033[0m\n" "$lvl" >&2
            for retry in $(seq 10 -1 0); do
                ! curl -sSLX GET                                            \
                    -H "Authorization: Bearer '"$GITLAB_CRED"'"             \
                    "'"$GITLAB_API"'/v4/groups/$(
                            set -e
                            printf "Mirrors%s/%s" "$dst_domain" "$dst_dir"  \
                            | cut -d/ -f-"$lvl"                             \
                            | sed "s/ /%20/g"                               \
                            | sed "s/\//%2F/g"                              \
                            | grep -v "[[:space:]]"
                        )"                                                  \
                | jq -er .id                                                \
                | grep "^[0-9][0-9]*$"                                      \
                || break
                if [ "$retry" -le 0 ]; then
                    printf "\033[31m[ERROR] Failed to create group level %d.\033[0m\n" "$lvl" >&2
                    exit 1
                fi
                curl -sSLX POST                                             \
                    -H "Authorization: Bearer '"$GITLAB_CRED"'"             \
                    -H "Content-Type: application/json"                     \
                    -d "{\"name\": \"$(
                            set -e
                            printf "Mirrors%s/%s" "$dst_domain" "$dst_dir"  \
                            | cut -d/ -f"$lvl"                              \
                            | grep -v "[[:space:]]"
                        )\", \"path\": \"$(
                            set -e
                            printf "Mirrors%s/%s" "$dst_domain" "$dst_dir"  \
                            | cut -d/ -f"$lvl"                              \
                            | grep -v "[[:space:]]"
                        )\", \"parent_id\": $(
                            set -e
                            printf "Mirrors%s/%s" "$dst_domain" "$dst_dir"  \
                            | cut -d/ -f-"$lvl"                             \
                            | sed "s/\/[^\/][^\/]*$//"                      \
                            | sed "s/ /%20/g"                               \
                            | sed "s/\//%2F/g"                              \
                            | grep -v "[[:space:]]"                         \
                            | grep .                                        \
                            | sed "'"s/^/$(
                                    set -e
                                    printf '%s' "$GITLAB_API/v4/groups/"    \
                                    | sed 's/\([\\\/\.\-]\)/\\\1/g'
                                )/"'"                                       \
                            | xargs -rn1 curl -sSLX GET                     \
                                -H "Authorization: Bearer '"$GITLAB_CRED"'" \
                            | jq -er .id                                    \
                            | grep "^[0-9][0-9]*$"
                        ), \"visibility\": \"public\"}"                     \
                    -o "/dev/stderr"                                        \
                    -w "%{http_code}\n"                                     \
                    "'"$GITLAB_API"'/v4/groups/"
            done
        done
    fi

    if git lfs ls-files | head -n1 | grep . >/dev/null || git lfs ls-files --deleted | head -n1 | grep . >/dev/null || git lfs ls-files -a | head -n1 | grep . >/dev/null; then
        git lfs fetch --all origin 2>&1 || true
        git remote set-url origin "$dst" 2>&1
        git lfs push --all origin 2>&1 || true
    fi
    git remote set-url origin "$dst" 2>&1
    git config remote.origin.mirror false
    git config --replace-all remote.origin.push "+refs/heads/*"
    git config --add         remote.origin.push "+refs/tags/*"
    git push -f         origin 2>&1 | grep -v "^Everything up-to-date$" | cat -
    git push -f --prune origin 2>&1 | grep -v "^Everything up-to-date$" | cat -
    git config --add         remote.origin.push "+refs/changes/*"
    # git config --add         remote.origin.push "+refs/keep-around/*"
    # git config --add         remote.origin.push "+refs/merge-requests/*"
    git config --add         remote.origin.push "+refs/meta/*"
    # git config --add         remote.origin.push "+refs/pipelines/*"
    git config --add         remote.origin.push "+refs/pull/*"

    if ! git push -fq origin 2>&1; then
        printf "\033[31m[ERROR] Unable to push all PR refs to \"%s\".\033[0m\n" "$dst" >&2
        queue="$(
                set -e
                printf "refs/%s/\n" \
                    "changes"       \
                    "meta"          \
                    "pull"          \
                | grep .
            )"
        while [ "$queue" ]; do
            cur="$(printf "%s" "$queue" | head -n1)"
            queue="$(printf "%s" "$queue" | tail -n+2)"
            ! git push -f origin "$cur*" 2>&1 || continue
            next="$(
                    set -e
                    git --no-pager show-ref     \
                    | cut -d" " -f2-            \
                    | sed -n "s/^\($(
                            set -e
                            printf "%s" "$cur"  \
                            | sed "s/\([\\\\\\/\\.\\-]\)/\\\\\\1/g"
                        ).\).*/\1/p"            \
                    | grep .                    \
                    | sort -Vu
                )"
            if [ "$(printf "%s" "$next" | wc -l | sed "s/^[[:space:]]*//" | sed "s/[[:space:]]$//")" -gt 1 ]; then
                printf "\033[33m[WARNING] Refine PR refs "%s" after push failure to \"%s\".\033[0m\n" "$cur*" "$dst" >&2
                queue="$(printf "%s\n" "$queue" "$next" | grep .)"
            else
                printf "\033[31m[ERROR] Unable to push PR refs "%s" to \"%s\".\033[0m\n" "$cur*" "$dst" >&2
            fi
        done
    fi

    if ! git push -fq --prune origin 2>&1; then
        printf "\033[31m[ERROR] Unable to prune PR refs on \"%s\".\033[0m\n" "$dst" >&2
    fi
    git config remote.origin.mirror true
    # git push --mirror origin 2>&1
    # git push -f --all  --prune origin 2>&1
    # git push -f --tags --prune origin 2>&1

    # GitLab-specific:
    # - Set visibility after checking.
    #   Credential with restrictive role(s) can be used for read-only checking.
    if '"$([ "$GITLAB_CRED" ] && printf 'true' || printf 'false')"'; then
        ! printf "Mirrors%s/%s" "$dst_domain" "$dst_dir"                        \
        | sed "s/ /%20/g"                                                       \
        | sed "s/\//%2F/g"                                                      \
        | grep -v "[[:space:]]"                                                 \
        | grep .                                                                \
        | sed "'"s/^/$(
                set -e
                printf '%s' "$GITLAB_API/v4/projects/"                          \
                | sed 's/\([\\\/\.\-]\)/\\\1/g'
            )/"'"                                                               \
        | xargs -rn1 curl -sSLX GET -H "Authorization: Bearer '"$GITLAB_CRED"'" \
        | jq -er ".visibility"                                                  \
        | grep -e "^internal$" -e "^private$"                                   \
        || printf "Mirrors%s/%s" "$dst_domain" "$dst_dir"                       \
        | sed "s/ /%20/g"                                                       \
        | sed "s/\//%2F/g"                                                      \
        | grep -v "[[:space:]]"                                                 \
        | grep .                                                                \
        | sed "'"s/^/$(
                set -e
                printf '%s' "$GITLAB_API/v4/projects/"                          \
                | sed 's/\([\\\/\.\-]\)/\\\1/g'
            )/"'"                                                               \
        | xargs -rn1 curl -sSLX PUT                                             \
            -H "Authorization: Bearer '"$GITLAB_CRED"'"                         \
            -d "visibility=public"                                              \
            -o "/dev/null"                                                      \
            -w "%{http_code}"                                                   \
        | grep "^200$"
    fi
' 2>&1 | tee "$log"

grep                                                                                            \
    -e 'Connection reset by'                                                                    \
    -e 'bytes of body are still expected'                                                       \
    -e 'client_loop: send disconnect'                                                           \
    -e 'error: RPC failed; curl 56 GnuTLS recv error (-9)'                                      \
    -e 'fatal: expected flush after ref listing'                                                \
    -e 'gnutls_handshake() failed: The TLS connection was non-properly terminated.'             \
    -e 'kex_exchange_identification: Connection closed by remote host'                          \
    -e 'unexpected disconnect while reading sideband packet'                                    \
    -i                                                                                          \
    "$log"                                                                                      \
| wc -l                                                                                         \
| grep -v '^0$'                                                                                 \
| xargs -r printf '\033[31m[ERROR] Found %d potential network failures in log.\033[0m\n' >&2

grep                                                                                                \
    -e 'Could not scan for Git LFS tree: missing object:'                                           \
    -e 'WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!'                                           \
    -e 'error: update_ref failed for ref'                                                           \
    -e 'fatal: Could not read from remote repository.'                                              \
    -e 'parse error: Invalid numeric literal at line'                                               \
    -e 'remote: GitLab: http post to gitlab api /post_receive endpoint: 500 Internal Server Error'  \
    -i                                                                                              \
    "$log"                                                                                          \
| wc -l                                                                                             \
| grep -v '^0$'                                                                                     \
| xargs -r printf '\033[31m[ERROR] Found %d potential non-network failures in log.\033[0m\n' >&2

paste -sd' ' "$log"                                                                                             \
| sed 's/remote: GitLab: The default branch of a project cannot be deleted\. *To *\([^ ]*\)/\n########\1\n/g'   \
| sed -n 's/^########//p'                                                                                       \
| sed 's/^\(git\.codingcafe\.org\):/https:\/\/\1\//'                                                            \
| sed 's/\.git$/\/\-\/settings\/repository/'                                                                    \
| xargs -r printf '\033[31m[ERROR] Potential branch renaming at: %s\033[0m\n' >&2

rm -f "$log"
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

date || true

trap - SIGTERM SIGINT EXIT
