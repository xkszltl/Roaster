#!/bin/bash

set -e

cd "$(dirname "$0")"
[ "$ROOT_DIR" ] || export ROOT_DIR="$(realpath ..)"
[ "$ROOT_DIR" ]
cd "$ROOT_DIR"

for cmd in jq; do
    ! which "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "%s".\033[0m\n' "$cmd" >&2
    exit 1
done

echo '----------------------------------------------------------------'
echo '           Measure link quality to docker hub mirrors           '
echo '----------------------------------------------------------------'

# - USTC mirror is only available on campus as of Feb 2024.
# - 163 mirror is online but without manifest as of Feb 2024.
# - Baidu mirror is online but without manifest as of Feb 2024.
. "$ROOT_DIR/geo/best-httping.sh"               \
    https://docker.io                           \
    https://docker.mirrors.sjtug.sjtu.edu.cn    \
    https://docker.nju.edu.cn                   \
    disabled-https://docker.mirrors.ustc.edu.cn \
    disabled-https://hub-mirror.c.163.com       \
    disabled-https://mirror.baidubce.com        \
    https://registry-1.docker.io                \
    https://registry.hub.docker.com
[ "$LINK_QUALITY" ]

printf '%s\n' "$LINK_QUALITY" | column -t | sed 's/^/| /'

echo '----------------------------------------------------------------'

[ "$DOCKER_MIRROR" ] || DOCKER_MIRROR="$(printf '%s\n' "$LINK_QUALITY" | cut -d' ' -f2)"
[ "$DOCKER_MIRROR" ]

sudo cat '/etc/docker/daemon.json'          \
| sudo tee '/etc/docker/daemon.json.bak'    \
| jq -e '.'
sudo cat '/etc/docker/daemon.json.bak'      \
| jq -Se '."registry-mirrors" |= []'        \
| sudo tee '/etc/docker/daemon.json.new'    \
> /dev/null

for url in $DOCKER_MIRROR; do
    sudo cat '/etc/docker/daemon.json.new'                                      \
    | jq -Se '."registry-mirrors"[."registry-mirrors" | length] |= "'"$url"'"'  \
    | sudo tee '/etc/docker/daemon.json.tmp'                                    \
    > /dev/null
    sudo mv -f '/etc/docker/daemon.json.'{tmp,new}
done
sudo rm -f '/etc/docker/daemon.json.tmp'
sudo mv -f '/etc/docker/daemon.json'{.new,}
sudo jq -e '.' '/etc/docker/daemon.json'

echo '========================================'
echo '| Done. Please restart docker daemon.'
echo '========================================'
