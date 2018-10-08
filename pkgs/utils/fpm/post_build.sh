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
find "./$INSTALL_PREFIX" -maxdepth 1 -type d -name 'lib*' | sed 's/\.//' | sed 's/\/\/*/\//g' > "./$PKG_LD_CONF_DIR/$(basename $(cd ../.. && pwd)).conf"

du -sh .{,{,/usr{,/local}}/*}

popd

# ----------------------------------------------------------------
# Wait for exclude-file generation in pre-build
# ----------------------------------------------------------------

wait
