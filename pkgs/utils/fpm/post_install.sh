#!/bin/sh

# ================================================================
# Post-install Script
# ================================================================

set -xe

# ----------------------------------------------------------------
# Clean up empty directory if necessary.
# ----------------------------------------------------------------

(
    set -xe
    cd /etc/ld.so.conf.d
    [ -d 'roaster.conf.d' ] && echo 'include roaster.conf.d/*.conf' > /etc/ld.so.conf.d/roaster.conf || rm -f roaster.conf
)

# ----------------------------------------------------------------
# Non-kernel refresh.
# ----------------------------------------------------------------

if which systemctl >/dev/null 2>&1 && systemctl is-system-running; then
    systemctl daemon-reload
else
    printf '\033[36m[INFO] Skip systemd refresh.\033[0m\n' >&2
fi

ldconfig

# ----------------------------------------------------------------
# Kernel refresh.
# ----------------------------------------------------------------

(
    set -ex

    # Namespaces used in cgroup v1.
    [ ! -e '/proc/1/cgroup' ]                                           \
    || ! cut -d: -f3- '/proc/1/cgroup'                                  \
    | grep -q -e'^/'{'docker','lxc'}'/'                                 \
    || exit 0

    # DNS mounts used in cgroup v2.
    [ ! -e '/proc/1/mountinfo' ]                                        \
    || ! cut -d' ' -f4 '/proc/1/mountinfo'                              \
    | grep -q '/docker/containers/[0-9A-Fa-f][0-9A-Fa-f]*/hostname'     \
    || ! cut -d' ' -f4 '/proc/1/mountinfo'                              \
    | grep -q '/docker/containers/[0-9A-Fa-f][0-9A-Fa-f]*/hosts'        \
    || ! cut -d' ' -f4 '/proc/1/mountinfo'                              \
    | grep -q '/docker/containers/[0-9A-Fa-f][0-9A-Fa-f]*/resolv\.conf' \
    || exit 0

    # Leaked by docker/podman.
    # They can also exist on host, if leaked out from previous bind mount.
    # Use with caution.
    [ ! -e '/.dockerenv'        ] || exit 0
    [ ! -e '/run/.containerenv' ] || exit 0

    sysctl --system
)
