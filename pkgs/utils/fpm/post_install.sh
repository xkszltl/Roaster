#!/bin/sh

# ================================================================
# Post-install Script
# ================================================================

set -xe

[ "$IS_CONTAINER" ] || export IS_CONTAINER=$([ -e /proc/1/cgroup ] && [ $(sed -n 's/^[^:]*:[^:]*:\(..\)/\1/p' /proc/1/cgroup | wc -l) -gt 0 ] && echo true || echo false)

# ----------------------------------------------------------------
# Clean up empty directory if necessary
# ----------------------------------------------------------------

pushd /etc/ld.so.conf.d
[ -d 'roaster.conf.d' ] && echo 'include roaster.conf.d/*.conf' > /etc/ld.so.conf.d/roaster.conf || rm -f roaster.conf
popd

# ----------------------------------------------------------------
# Refresh
# ----------------------------------------------------------------

systemctl daemon-reload || $IS_CONTAINER
ldconfig
sysctl --system || $IS_CONTAINER
