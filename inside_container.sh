#!/bin/bash

set -e

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

[ ! -e '/proc/1/mountinfo' ]                                        \
|| ! cut -d' ' -f4 '/proc/1/mountinfo'                              \
| grep -q '/docker/buildkit/executor/hosts'                         \
|| ! cut -d' ' -f4 '/proc/1/mountinfo'                              \
| grep -q '/docker/buildkit/executor/resolv\.conf'                  \
|| exit 0

# Leaked by docker/podman.
# They can also exist on host, if leaked out from previous bind mount.
# Use with caution.
[ ! -e '/.dockerenv'        ]                                       \
|| exit 0
[ ! -e '/run/.containerenv' ]                                       \
|| exit 0

exit 1
