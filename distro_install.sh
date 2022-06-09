#!/bin/bash

# ============================================================
# Install pkgs from distro with some bootstraping supports.
# List cmd[,pkg] as args.
# ============================================================

set -e

libs="$*"

. <(sed 's/^\(..*\)/export DISTRO_\1/' '/etc/os-release')

# Add distro-specific libs.

case "$DISTRO_ID-$DISTRO_VERSION_ID" in
'centos-7' | 'rhel-7')
    libs="which,which dnf,nextgen-yum4 dnf,dnf-plugins-core $libs"
    ;;
'centos-'* | 'fedora-'* | 'rhel-'* | 'scientific-'*)
    libs="which,which $libs"
    ;;
esac
libs="sudo,sudo $libs"

# Scan for missing libs.
# Known issues:
# - CentOS docker does not have which pre-installed.

pkgs=''
for pkg in $libs; do
    which "$(cut -d, -f1 <<< "$pkg")" >/dev/null 2>&1 || pkgs="$pkgs $(cut -d, -f2 <<< "$pkg,$pkg")"
done
[ "$pkgs" ] || exit 0

# Pull distro repo.

case "$DISTRO_ID" in
'centos' | 'fedora' | 'rhel' | 'scientific')
    $(! which sudo >/dev/null || echo sudo) which dnf >/dev/null 2>&1 && dnf makecache -y || $(! which sudo >/dev/null || echo sudo) yum makecache -y
    ;;
'debian' | 'linuxmint' | 'ubuntu')
    $(! which sudo >/dev/null || echo sudo) apt-get update -y
    ;;
esac

# Install libs.

if ! which sudo; then
    case "$DISTRO_ID" in
    'centos' | 'fedora' | 'rhel')
        which dnf >/dev/null 2>&1 && dnf install -y sudo || yum install -y sudo
        ;;
    'debian' | 'linuxmint' | 'ubuntu' | 'scientific')
        DEBIAN_FRONTEND=noninteractive apt-get install -y sudo
        ;;
    esac
fi

case "$DISTRO_ID" in
'centos' | 'fedora' | 'rhel' | 'scientific')
    for pkg in $pkgs; do
        which dnf >/dev/null 2>&1 && sudo dnf install -y "$pkg" || sudo yum install -y "$pkg"
    done
    sudo which dnf >/dev/null 2>&1 && sudo dnf autoremove -y || sudo yum autoremove -y
    ! sudo which dnf >/dev/null 2>&1 || sudo dnf clean all --enablerepo='*'
    sudo yum clean all
    sudo rm -rf /var/cache/yum
    sudo rm -rf /var/log/dnf.librepo.log*
    ;;
'debian' | 'linuxmint' | 'ubuntu')
    for pkg in $pkgs; do
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
    done
    sudo apt-get autoremove -y
    sudo apt-get clean
    sudo rm -rf /var/lib/apt/lists/*
    ;;
esac
