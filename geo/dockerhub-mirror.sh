#!/bin/bash

set -e

cd "$(dirname "$0")"
[ "$ROOT_DIR" ] || export ROOT_DIR="$(readlink -e ..)"
[ "$ROOT_DIR" ]
cd "$ROOT_DIR"

for cmd in jq; do
    which "$cmd" > /dev/null
done

echo '----------------------------------------------------------------'
echo '           Measure link quality to docker hub mirrors           '
echo '----------------------------------------------------------------'

. "$ROOT_DIR/geo/best-httping.sh"       \
    https://docker.io                   \
    https://docker.mirrors.ustc.edu.cn  \
    https://hub-mirror.c.163.com        \
    https://mirror.baidubce.com         \
    https://registry-1.docker.io        \
    https://registry.hub.docker.com
[ "$LINK_QUALITY" ]

column -t <<< "$LINK_QUALITY" | sed 's/^/| /'

echo '----------------------------------------------------------------'

[ "$DOCKER_MIRROR" ] || DOCKER_MIRROR="$(cut -d' ' -f2 <<< "$LINK_QUALITY")"
[ "$DOCKER_MIRROR" ]

sudo cat '/etc/docker/daemon.json'          \
| sudo tee '/etc/docker/daemon.json.bak'    \
| jq -e '.'
sudo cat '/etc/docker/daemon.json.bak'      \
| jq -e '."registry-mirrors" |= []'         \
| sudo tee '/etc/docker/daemon.json.new'    \
> /dev/null

for url in $DOCKER_MIRROR; do
    sudo cat '/etc/docker/daemon.json.new'                                      \
    | jq -e '."registry-mirrors"[."registry-mirrors" | length] |= "'"$url"'"'   \
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
