#!/bin/bash

# ================================================================
# Post-build Script
# ================================================================

# ----------------------------------------------------------------
# Generate search path file for ldconfig
# ----------------------------------------------------------------

pushd "$INSTALL_ROOT"

# Relocate pkg-config.
find "./$INSTALL_PREFIX" -name '*.pc' -type f | xargs -r sed -i "s/$(sed 's/\/*$//' <<< "$INSTALL_ROOT" | sed 's/\([\\\/\.\-]\)/\\\1/g')//g"

export PKG_LD_CONF_DIR="/etc/ld.so.conf.d/roaster.conf.d"

mkdir -p "./$PKG_LD_CONF_DIR"
find "./$INSTALL_PREFIX" -maxdepth 1 -type d -name 'lib*' | sed 's/\.//' | sed 's/\/\/*/\//g' > "./$PKG_LD_CONF_DIR/$(basename $(cd ../.. && pwd)).conf"

du -sh .{,{,/usr{,/local}}/*}

popd

# ----------------------------------------------------------------
# Wait for exclude-file generation in pre-build
# ----------------------------------------------------------------

wait
