#!/bin/bash

set -e +x

cd "$(dirname "$0")"

for cmd in docker grep jq rsync sed xargs; do
    ! which "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "%s".\033[0m\n' "$cmd" >&2
    exit 1
done

sudo_docker="$([ -w '/var/run/docker.sock' ] || ! which sudo >/dev/null || echo 'sudo --preserve-env=DOCKER_BUILDKIT') docker"

[ "$n_layers" ] || n_layers=31
if [ "$n_layers" -le 0 ]; then
    printf '\033[31m[ERROR] Invalid number of layers %d.\033[0m\n' "$n_layers" >&2
    exit 1
fi
for i in $(seq 1 "$n_layers"); do
    [ "$i" -gt 1 ] || continue
    [ "$(expr "$i" '*' "$i")" -le "$n_layers" ] || break
    [ "$(expr "$n_layers" % "$i")" -eq 0 ] || continue
    printf '\033[33m[WARNING] Use prime number of layers instead of %d for uniformity.\033[0m\n' "$n_layers" >&2
    break
done
if [ ! "$src" ]; then
    printf '\033[31m[ERROR] Missing source tag $src.\033[0m\n' >&2
    exit 1
fi
if [ ! "$dst" ]; then
    printf '\033[31m[ERROR] Missing destination tag $dst.\033[0m\n' >&2
    exit 1
fi

ctx="$(mktemp -dt "$(basename "$0")-build-ctx-XXXXXXXX")"
trap "trap - SIGTERM; $(sed 's/^\(..*\)$/rm \-rf "\1"/' <<< "$ctx"); kill -- -'$$'" SIGINT SIGTERM EXIT

touch "$ctx/dummy.sh"
chmod +x "$ctx/dummy.sh"
[ "$pre"  ] || pre="$ctx/./dummy.sh"
[ "$post" ] || post="$ctx/./dummy.sh"

cat << EOF | tee "$ctx/Dockerfile"
ARG base='$(./docker_from.sh "$src")'
ARG src='$src'

FROM "\$base" AS base
FROM "\$src" AS src

FROM scratch AS util-install
COPY distro_install.sh /

FROM scratch AS util-post
COPY post/ /

FROM scratch AS util-pre
COPY pre/ /

FROM scratch AS util-slice
COPY docker_slice.sh /

FROM src AS pre
RUN --mount=type=bind,from=util-pre,target=/mnt/util-pre                                            \\
    set -e;                                                                                         \\
    '/mnt/util-pre/$(sed 's/\/\.\//'"$(printf '\v')"'/' <<< "$pre" | cut -d"$(printf '\v')" -f2)';  \\
    truncate -s0 ~/.bash_history;

FROM base AS bootstrap
RUN --mount=type=bind,from=util-install,target=/mnt/util-install    \\
    set -e;                                                         \\
    . '/etc/os-release';                                            \\
    case "\$ID" in                                                  \\
    'centos' | 'fedora' | 'rhel' | 'scientific')                    \\
        /mnt/util-install/distro_install.sh ,epel-release;          \\
        ;;                                                          \\
    esac;                                                           \\
    truncate -s0 ~/.bash_history;
RUN --mount=type=bind,from=util-install,target=/mnt/util-install                                    \\
    set -e;                                                                                         \\
    /mnt/util-install/distro_install.sh chrpath ,coreutils find,findutils grep parallel rsync sed;  \\
    echo 'will cite' | sudo parallel --citation || sudo parallel --will-cite < /dev/null;           \\
    truncate -s0 ~/.bash_history;

FROM bootstrap AS util-bin
RUN --mount=type=bind,from=util-install,target=/mnt/util-install    \\
    set -e;                                                         \\
    echo '#!/bin/sh' > /env.sh;                                     \\
    chmod +x /env.sh;                                               \\
    echo "\$PATH"                                                   \\
    | tr ':' '\\n'                                                  \\
    | sed -n 's/^\\//\\/mnt\\/util\\-bin\\//p'                      \\
    | paste -sd: -                                                  \\
    | sed 's/\\(..*\\)/'"'"'\\1'"'/"                                \\
    | sed 's/\$/:\\\$PATH/'                                         \\
    | xargs -rI{} printf "export %s=%s\\n" 'PATH'            {}     \\
    >> /env.sh;                                                     \\
    echo "\$LD_LIBRARY_PATH"                                        \\
    | tr ':' '\\n'                                                  \\
    | sed -n 's/^\\//\\/mnt\\/util\\-bin\\//p'                      \\
    | paste -sd: -                                                  \\
    | sed 's/\\(..*\\)/'"'"'\\1'"'/"                                \\
    | sed 's/\$/:\\\$LD_LIBRARY_PATH/'                              \\
    | xargs -rI{} printf "export %s=%s\\n" 'LD_LIBRARY_PATH' {}     \\
    >> /env.sh;                                                     \\
    ldconfig -Nv 2>/dev/null                                        \\
    | grep '^/'                                                     \\
    | cut -d: -f1                                                   \\
    | sed -n 's/^\\//\\/mnt\\/util\\-bin\\//p'                      \\
    | paste -sd: -                                                  \\
    | sed 's/\\(..*\\)/'"'"'\\1'"'/"                                \\
    | sed 's/\$/:\\\$LD_LIBRARY_PATH/'                              \\
    | xargs -rI{} printf "export %s=%s\\n" 'LD_LIBRARY_PATH' {}     \\
    >> /env.sh;                                                     \\
    for bin in perl; do                                             \\
        which perl                                                  \\
        | xargs -rI{} chrpath -l {}                                 \\
        | cut -d: -f2                                               \\
        | cut -d= -f2                                               \\
        | sed -n 's/^\\//\\/mnt\\/util\\-bin\//p'                   \\
        | paste -sd: -                                              \\
        | sed 's/\\(..*\\)/'"'"'\\1'"'/"                            \\
        | sed 's/\$/:\\\$LD_LIBRARY_PATH/'                          \\
        | xargs -rI{} printf "export %s=%s\\n" 'LD_LIBRARY_PATH' {} \\
        >> /env.sh;                                                 \\
    done;                                                           \\
    truncate -s0 ~/.bash_history;

FROM bootstrap AS slice
$(seq "$n_layers" | xargs -rI{} printf 'RUN --mount=type=bind,from=pre,target=/mnt/pre --mount=type=bind,from=util-slice,target=/mnt/util-slice --mount=type=bind,from=util-bin,target=/mnt/util-bin set -e; . /mnt/util-bin/env.sh; src=/mnt/pre dst=/ layer="%d" n_layers="%d" /mnt/util-slice/docker_slice.sh\n' {} "$n_layers")

FROM slice AS metadata
$($sudo_docker inspect "$src" | jq -ce '.[0].Config.Entrypoint'   | grep -v '^null$' | sed -n 's/^\(.\)/ENTRYPOINT \1/p')
$($sudo_docker inspect "$src" | jq -ce '.[0].Config.Cmd'          | grep -v '^null$' | sed -n 's/^\(.\)/CMD \1/p'       )
$($sudo_docker inspect "$src" | jq -ce '.[0].Config.Env[]'        | grep -v '^null$' | sed -n 's/^"\([^=]*=\)\(.*\)"$/ENV \1'"'"'\2'"'"'/p'                 | grep '.' | sort -u)
$($sudo_docker inspect "$src" | jq -ce '.[0].Config.ExposedPorts' | grep -v '^null$' | jq -cer 'keys[] | "EXPOSE " + .'                                     | grep '.' | sort -u)
$($sudo_docker inspect "$src" | jq -ce '.[0].Config.Labels'       | grep -v '^null$' | jq -cer "to_entries[] | \"LABEL \" + .key + \"='\" + .value + \"'\"" | grep '.' | sort -u)
$($sudo_docker inspect "$src" | jq -ce '.[0].Config.Shell'        | grep -v '^null$' | sed -n 's/^\(.\)/SHELL \1/p'     )
$($sudo_docker inspect "$src" | jq -ce '.[0].Config.StopSignal'   | grep -v '^null$' | sed -n 's/^\(.\)/STOPSIGNAL \1/p')
$($sudo_docker inspect "$src" | jq -ce '.[0].Config.User'         | grep -v '^null$' | sed -n 's/^\(.\)/USER \1/p'      )
$($sudo_docker inspect "$src" | jq -ce '.[0].Config.Volumes'      | grep -v '^null$' | jq -cer 'keys[] | "VOLUME [\"" + . + "\"]"'                          | grep '.' | sort -u)
$($sudo_docker inspect "$src" | jq -ce '.[0].Config.WorkingDir'   | grep -v '^null$' | sed -n 's/^\(.\)/WORKDIR \1/p'   )

FROM metadata AS post
RUN --mount=type=bind,from=util-post,target=/mnt/util-post \\
    set -e; \\
    '/mnt/util-post/$(sed 's/\/\.\//'$(printf '\v')'/' <<< "$post" | cut -d"$(printf '\v')" -f2)'; \\
    truncate -s0 ~/.bash_history;

FROM post AS dst
EOF

cp -f distro_install.sh docker_slice.sh "$ctx/"
rsync -RPa "$(sed 's/\(\/\.\/[^\/][^\/]*\/\).*/\1/' <<< "$pre")"  "$ctx/pre/"
rsync -RPa "$(sed 's/\(\/\.\/[^\/][^\/]*\/\).*/\1/' <<< "$post")" "$ctx/post/"

DOCKER_BUILDKIT=1 $sudo_docker build --progress plain -t "$dst" "$ctx"

rm -rf "$ctx"
trap - SIGINT SIGTERM EXIT
