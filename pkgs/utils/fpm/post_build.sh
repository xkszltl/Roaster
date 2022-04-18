#!/bin/bash

# ================================================================
# Post-build Script
# ================================================================

# ----------------------------------------------------------------
# Generate search path file for ldconfig
# ----------------------------------------------------------------

pushd "$INSTALL_ROOT"

# Relocate pkg-config.
find "./$INSTALL_PREFIX" -name '*.pc' -type f | xargs -r sed -i "s/$(sed 's/\/*$//' <<< "$INSTALL_ABS" | sed 's/\([\\\/\.\-]\)/\\\1/g')/$(sed 's/\/*$//' <<< "$INSTALL_PREFIX" | sed 's/\([\\\/\.\-]\)/\\\1/g')/g"

export PKG_LD_CONF_DIR="/etc/ld.so.conf.d/roaster.conf.d"

mkdir -p "./$PKG_LD_CONF_DIR"
find "./$INSTALL_PREFIX" -maxdepth 1 -type d -name 'lib*'   \
| sed 's/\/\/*/\//g'                                        \
| sed 's/^\.\//\//'                                         \
>> "./$PKG_LD_CONF_DIR/$(basename $(cd ../.. && pwd)).conf"

# Add target triple.
#   - Vendor can be anything, including "unknown".
#   - GCC/LLVM uses "linux"/"linux-gnu" in target triple.
find "./$INSTALL_PREFIX" -maxdepth 1 -type d -name 'lib*'                                                                       \
| xargs -rI{} find {} -mindepth 1 -maxdepth 1 -type d '(' -name "$(uname -m)-*-linux" -o -name "$(uname -m)-*-linux-gnu" ')'    \
| sed 's/\/\/*/\//g'                                                                                                            \
| sed 's/^\.\//\//'                                                                                                             \
>> "./$PKG_LD_CONF_DIR/$(basename $(cd ../.. && pwd)).conf"

du -sh .{,{,/usr{,/local}}/*}

popd

# ----------------------------------------------------------------
# Wait for exclude-file generation in pre-build
# ----------------------------------------------------------------

wait
