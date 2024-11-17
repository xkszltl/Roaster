#!/bin/bash

# ============================================================
# Guesstimate the distro base docker for an image.
# This info does not exist outside of Dockerfile.
# Need to use distro metadata to route to a public image.
# ============================================================

set -e +x >&2

cd "$(dirname "$0")"

for cmd in docker sed; do
    ! which "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "$s".\033[0m\n' "$cmd" >&2
    exit 1
done

sudo_docker="$([ -w '/var/run/docker.sock' ] || ! which sudo >/dev/null || echo 'sudo --preserve-env=DOCKER_BUILDKIT') docker"

if [ "$#" -ne 1 ]; then
    printf '\033[31m[ERROR] Specify exactly 1 docker tag instead of "%s".\033[0m\n' "$*" >&2
    exit 1
fi

eval "$($sudo_docker run --entrypoint '' --rm "$1" cat '/etc/os-release' 2>/dev/null | sed 's/^\(..*\)/DISTRO_\1/')"

case "$DISTRO_ID-$DISTRO_VERSION_ID" in
'almalinux-'* | 'alpine-'* | 'centos-'* | 'debian-'* | 'fedora-'* | 'photon-'* | 'ubuntu-'*)
    echo "$DISTRO_ID:$DISTRO_VERSION_ID"
    ;;
'altlinux-'*)
    echo "$(sed 's/linux$//' <<< "$DISTRO_ID"):$DISTRO_VERSION_ID"
    ;;
'amzn-'*)
    echo "amazonlinux:$DISTRO_VERSION_ID"
    ;;
'arch-'*)
    echo "$DISTRO_ID""linux:base"
    ;;
'openEuler-'*)
    echo "$(tr '[A-Z]' '[a-z]' <<< "$DISTRO_ID/$DISTRO_ID:$DISTRO_VERSION_ID")"
    ;;
'opensuse-leap-'*)
    echo "$(tr '-' '/' <<< "$DISTRO_ID"):$DISTRO_VERSION_ID"
    ;;
'opensuse-tumbleweed-'*)
    echo "$(tr '-' '/' <<< "$DISTRO_ID"):latest"
    ;;
'openwrt-'*)
    echo "openwrtorg/rootfs:$DISTRO_VERSION_ID"
    ;;
'rocky-'*)
    echo "$DISTRO_ID""linux:$DISTRO_VERSION_ID"
    ;;
'scientific-'*)
    echo "sl:$(cut -d. -f1 <<< "$$DISTRO_VERSION_ID")"
    ;;
*)
    echo 'scratch'
    printf '\033[33m[WARNING] Unknown distro "%s".\033[0m\n' "$DISTRO_ID-$DISTRO_VERSION_ID" >&2
    ;;
esac
