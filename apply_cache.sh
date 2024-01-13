#!/bin/bash

set -xe

. <(sed 's/^\(..*\)/export DISTRO_\1/' '/etc/os-release')

export ROOT_DIR="$(realpath -e "$(dirname $0)")"

case "$DISTRO_ID-$DISTRO_VERSION_ID" in
'centos-'* | 'fedora-'* | 'rhel-'* | 'scientific-'*)
    if [ $# -le 0 ]; then
        $0                                                                              \
            {updates,extras,centosplus,runner_gitlab-runner,gitlab_gitlab-ce}{,-source} \
            {base,epel,centos-sclo-{sclo,rh},docker-ce-stable}{,-source,-debuginfo}     \
            dotnet                                                                      \
            oneAPI                                                                      \
            "cuda-rhel$DISTRO_VERSION_ID-$(uname -m)" libnvidia-container nvidia-{container-runtime,docker,machine-learning}
        exit $?
    fi

    [ "$RPM_CACHE_REPO" ] || export RPM_CACHE_REPO="/etc/yum.repos.d/codingcafe-mirror.repo"

    for i in $(ls "$ROOT_DIR/repos/"*.repo); do
        [ ! -f "/etc/yum.repos.d/$(basename "$i")" ] || continue
        repo_tmp="$(mktemp -d "repo_tmp.XXXXXXXXXX")"
        cat "$i"                                                                                        \
        | sed 's/^\([[:space:]]*\[.*\)\$basearch\(.*\]\)[[:space:]]*$/\1'"$(uname -m)"'\2/g'            \
        | sed 's/^\([[:space:]]*\[.*\)\$releasever\(.*\]\)[[:space:]]*$/\1'"$DISTRO_VERSION_ID"'\2/g'   \
        | tee "$repo_tmp/$(basename "$i")"
        sudo yum-config-manager --add-repo "$repo_tmp/$(basename "$i")"
        rm -rf "$repo_tmp"
    done

    [ "$RPM_PRIORITY" ] && xargs -n1 <<<$@ | sed 's/\(.*\)/\1 cache-\1/' | xargs -n1 | sed "s/\(.*\)/--save --setopt=\1\.priority=$RPM_PRIORITY/" | xargs sudo yum-config-manager
    xargs -n1 <<<$@ | sed "s/^/--disable $([ -f "$RPM_CACHE_REPO" ] || echo cache-)/" | xargs sudo yum-config-manager
    xargs -n1 <<<$@ | sed "s/^/--enable  $([ -f "$RPM_CACHE_REPO" ] && echo cache-)/" | xargs sudo yum-config-manager

    sync

    sudo yum repolist -y
    ;;
'debian-'* | 'linuxmint-'* | 'ubuntu-'*)
    if [ $# -le 0 ]; then
        $0                  \
            cuda            \
            docker-ce       \
            intel-oneapi
        exit $?
    fi

    [ "$DEB_MIRROR_REPO" ] || export DEB_MIRROR_REPO="/etc/apt/sources.list.d/codingcafe-mirror.list"

    for i in $@; do
        [ -f "$ROOT_DIR/repos/codingcafe-mirror-$i.list" ] || continue
        [ ! -f "/etc/apt/sources.list.d/codingcafe-mirror-$i.list" ] || continue
        cat "$ROOT_DIR/repos/codingcafe-mirror-$i.list"     \
        | sed 's/^\(.*\)/printf "%s\\n" "\1"/'              \
        | bash                                              \
        | sudo tee "/etc/apt/sources.list.d/codingcafe-mirror-$i.list"
        sudo mv -f "/etc/apt/sources.list.d/$i.list"{,.bak}
    done
    sync
    ;;
esac
