#!/bin/bash

set -e

pushd /etc/docker

echo '========================================'
echo '| Before'
echo '========================================'

cat 'daemon.json' | tee 'daemon.json.bak' | jq -e '.'

echo '========================================'
echo '| After'
echo '========================================'

cat 'daemon.json.bak'                                                                                       \
| jq -e '. |= . + {"default-runtime":"nvidia"}'                                                             \
| jq -e '. |= . + {"experimental":true}'                                                                    \
| jq -e '. |= . + {"max-concurrent-downloads":1024}'                                                        \
| jq -e '. |= . + {"max-concurrent-uploads":1024}'                                                          \
| jq -e '. |= . + {"storage-driver":"devicemapper"}'                                                        \
| jq -e '. |= . + {"storage-opts":[]}'                                                                      \
| jq -e '."storage-opts"[."storage-opts" | length] |= . + "dm.thinpooldev=/dev/mapper/Mocha-docker--pool"'  \
| jq -e '."storage-opts"[."storage-opts" | length] |= . + "dm.use_deferred_removal=true"'                   \
| jq -e '."storage-opts"[."storage-opts" | length] |= . + "dm.use_deferred_deletion=true"'                  \
| jq -e '. |= . + {"storage-driver":"overlay2"}'                                                            \
| jq -e '. |= . + {"storage-opts":[]}'                                                                      \
| tee 'daemon.json' | jq -e '.'                                                                             \
|| ( set -e
    cat 'daemon.json.bak' > 'daemon.json'
    false
)
