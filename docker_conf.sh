#!/bin/bash

set -e

sudo echo 'Permission granted.'

export ROOT_DIR="$(readlink -e "$(dirname "$0")")"

cd "$ROOT_DIR"
. pkgs/env/cred.sh

echo '========================================'
echo '| HTTP Proxy'
echo '========================================'

sudo mkdir -p '/etc/systemd/system/docker.service.d'

echo "# This file is auto-generated and may be overwritten.

[Service]
Environment=\"HTTP_PROXY=$CRED_USR_PRIVOXY_ADDR:$CRED_USR_PRIVOXY_PORT\"
Environment=\"HTTPS_PROXY=$CRED_USR_PRIVOXY_ADDR:$CRED_USR_PRIVOXY_PORT\"
Environment=\"NO_PROXY=127.0.0.1,::1,localhost,docker.codingcafe.org,git.codingcafe.org\"
" | sudo tee '/etc/systemd/system/docker.service.d/http-proxy.conf'

sudo systemctl daemon-reload || true
# sudo systemctl restart docker

echo '========================================'
echo '| Daemon JSON (Before)'
echo '========================================'

sudo [ -e '/etc/docker/daemon.json' ] || sudo echo '{}' > '/etc/docker/daemon.json'
sudo cat '/etc/docker/daemon.json' | sudo tee '/etc/docker/daemon.json.bak' | jq -e '.'

echo '========================================'
echo '| Daemon JSON (After)'
echo '========================================'

sudo cat '/etc/docker/daemon.json.bak'                                                                      \
| jq -e '. |= . + {"data-root":"/media/Scratch/docker"}'                                                    \
| jq -e '. |= . + {"debug":false}'                                                                          \
| jq -e '. |= . + {"default-runtime":"nvidia"}'                                                             \
| jq -e '. |= . + {"experimental":true}'                                                                    \
| jq -e '. |= . + {"features":{}}'                                                                          \
| jq -e '."features" |= ."features" + {"buildkit":true}'                                                    \
| jq -e '. |= . + {"max-concurrent-downloads":1024}'                                                        \
| jq -e '. |= . + {"max-concurrent-uploads":1024}'                                                          \
| jq -e '. |= . + {"storage-driver":"devicemapper"}'                                                        \
| jq -e '. |= . + {"storage-opts":[]}'                                                                      \
| jq -e '."storage-opts"[."storage-opts" | length] |= . + "dm.thinpooldev=/dev/mapper/Mocha-docker--pool"'  \
| jq -e '."storage-opts"[."storage-opts" | length] |= . + "dm.use_deferred_removal=true"'                   \
| jq -e '."storage-opts"[."storage-opts" | length] |= . + "dm.use_deferred_deletion=true"'                  \
| jq -e '. |= . + {"storage-driver":"overlay2"}'                                                            \
| jq -e '. |= . + {"storage-opts":[]}'                                                                      \
| sudo tee '/etc/docker/daemon.json' | jq -e '.'                                                            \
|| ( set -e
    sudo cat '/etc/docker/daemon.json.bak' > '/etc/docker/daemon.json'
    false
)

echo '========================================'
echo '| Done. Please restart docker daemon.'
echo '========================================'
