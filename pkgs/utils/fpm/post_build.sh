#!/bin/bash

pushd "$INSTALL_ROOT"

mkdir -p "etc/codingcafe.conf.d"
find "./$INSTALL_PREFIX" -maxdepth 1 -type d -name 'lib*' | sed 's/\.//' | sed 's/\/\/*/\//g' > "etc/codingcafe.conf.d/$(basename $(dirname $(pwd))).conf"

popd

[ "$FPM_EXCLUDE" ] || ! rpm -q filesystem || export FPM_EXCLUDE="$(repoquery -l filesystem)"
