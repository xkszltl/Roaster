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

cat 'daemon.json.bak'                                                                               \
| jq '. |= . + {"storage_driver":"devicemapper"}'                                                   \
| jq '. |= . + {"storage_opts":[]}'                                                                 \
| jq '.storage_opts[.storage_opts | length] |= . + "dm.thinpooldev=/dev/mapper/Mocha-docker--pool"' \
| jq '.storage_opts[.storage_opts | length] |= . + "dm.use_deferred_removal=true"'                  \
| jq '.storage_opts[.storage_opts | length] |= . + "dm.use_deferred_deletion=true"'                 \
| tee 'daemon.json' | jq '.'
