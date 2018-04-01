#!/bin/bash

# ================================================================
# Post-build Script
# ================================================================

# ----------------------------------------------------------------
# Generate search path file for ldconfig
# ----------------------------------------------------------------

pushd "$INSTALL_ROOT"

export PKG_LD_CONF_DIR="/etc/ld.so.conf.d/codingcafe.conf.d"

mkdir -p "./$PKG_LD_CONF_DIR"
find "./$INSTALL_PREFIX" -maxdepth 1 -type d -name 'lib*' | sed 's/\.//' | sed 's/\/\/*/\//g' > "./$PKG_LD_CONF_DIR/$(basename $(dirname $(pwd))).conf"

popd

# ----------------------------------------------------------------
# Warm-up cache for exclude-file
# ----------------------------------------------------------------

[ "$FPM_EXCLUDE" ] || ! rpm -q filesystem || export FPM_EXCLUDE="$(rpm -ql filesystem)"
