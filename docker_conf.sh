#!/bin/bash

set -e

pushd /etc/docker

echo '========================================'
echo '| Before'
echo '========================================'

cat 'daemon.json' | tee 'daemon.json.bak' | jq '.'

echo '========================================'
echo '| After'
echo '========================================'

cat 'daemon.json.bak'                                                                                   \
| jq '. |= . + {"storage-driver":"devicemapper"}'                                                       \
| jq '. |= . + {"storage-opts":[]}'                                                                     \
| jq '."storage-opts"[."storage-opts" | length] |= . + "dm.thinpooldev=/dev/mapper/Mocha-docker--pool"' \
| jq '."storage-opts"[."storage-opts" | length] |= . + "dm.use_deferred_removal=true"'                  \
| jq '."storage-opts"[."storage-opts" | length] |= . + "dm.use_deferred_deletion=true"'                 \
| tee 'daemon.json' | jq '.'                                                                            \
|| ( set -e
    cat 'daemon.json.bak' > 'daemon.json'
    false
)
