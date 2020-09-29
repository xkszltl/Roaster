#!/bin/bash

set -xe

. <(sed 's/^\(..*\)/export DISTRO_\1/' '/etc/os-release')

if [ $# -le 0 ]; then
    $0                                                                              \
        {updates,extras,centosplus,runner_gitlab-runner,gitlab_gitlab-ce}{,-source} \
        {base,epel,centos-sclo-{sclo,rh},docker-ce-stable}{,-source,-debuginfo}     \
        dotnet                                                                      \
        "cuda-$DISTRO_VERSION_ID-$(uname -i)" libnvidia-container nvidia-{container-runtime,docker,machine-learning}
    exit $?
fi

export ROOT_DIR="$(readlink -e "$(dirname $0)")"

[ "$RPM_CACHE_REPO" ] || export RPM_CACHE_REPO="/etc/yum.repos.d/codingcafe-cache.repo"

for i in $(ls "$ROOT_DIR/repos/"*.repo); do
    [ ! -f "/etc/yum.repos.d/$(basename "$i")" ] || continue
    repo_tmp="$(mktemp "repo_tmp.XXXXXXXXXX.repo")"
    cat "$i"                                                                                        \
    | sed 's/^\([[:space:]]*\[.*\)\$basearch\(.*\]\)[[:space:]]*$/\1'"$(uname -i)"'\2/g'            \
    | sed 's/^\([[:space:]]*\[.*\)\$releasever\(.*\]\)[[:space:]]*$/\1'"$DISTRO_VERSION_ID"'\2/g'   \
    | tee "$repo_tmp"
    sudo yum-config-manager --add-repo "$repo_tmp"
    rm -rf "$repo_tmp"
done

[ "$RPM_PRIORITY" ] && xargs -n1 <<<$@ | sed 's/\(.*\)/\1 cache-\1/' | xargs -n1 | sed "s/\(.*\)/--save --setopt=\1\.priority=$RPM_PRIORITY/" | xargs sudo yum-config-manager
xargs -n1 <<<$@ | sed "s/^/--disable $([ -f "$RPM_CACHE_REPO" ] || echo cache-)/" | xargs sudo yum-config-manager
xargs -n1 <<<$@ | sed "s/^/--enable  $([ -f "$RPM_CACHE_REPO" ] && echo cache-)/" | xargs sudo yum-config-manager

sync

sudo yum repolist
