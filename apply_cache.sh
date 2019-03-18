#!/bin/bash

set -e

if [ $# -le 0 ]; then
    $0                                                                              \
        {updates,extras,centosplus,runner_gitlab-runner,gitlab_gitlab-ce}{,-source} \
        {base,epel,centos-sclo-{sclo,rh},docker-ce-stable}{,-source,-debuginfo}     \
        cuda nvidia-machine-learning
    exit $?
fi

export ROOT_DIR=$(cd $(dirname $0) && pwd)

[ $RPM_CACHE_REPO ] || export RPM_CACHE_REPO=/etc/yum.repos.d/cache.repo

for i in $(ls $ROOT_DIR/repos/*.repo); do
    [ -f /etc/yum.repos.d/$(basename $i) ] || sudo yum-config-manager --add-repo $i
done

xargs -n1 <<<$@ | sed "s/^/--disable $([ -f $RPM_CACHE_REPO ] || echo cache-)/" | xargs sudo yum-config-manager
xargs -n1 <<<$@ | sed "s/^/--enable  $([ -f $RPM_CACHE_REPO ] && echo cache-)/" | xargs sudo yum-config-manager
sync

sudo yum repolist
