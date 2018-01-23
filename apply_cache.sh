#!/bin/bash

set -e

if [ $# -le 0 ]; then
    $0 {{updates,extras,centosplus,runner_gitlab-ci-multi-runner,gitlab_gitlab-ce}{,-source},{base,epel,centos-sclo-{sclo,rh},docker-ce-stable}{,-source,-debuginfo},cuda}
    exit $?
fi

export ROOT_DIR=$(cd $(dirname $0) && pwd)

[ $RPM_CACHE_REPO ] || export RPM_CACHE_REPO=/etc/yum.repos.d/cache.repo

for i in $(ls $ROOT_DIR/repos/*.repo); do
    [ -f /etc/yum.repos.d/$(basename $i) ] || cat $i > /etc/yum.repos.d/$(basename $i)
done

yum-config-manager $(xargs -n1 -I{} echo "--disable {}" <<<$@ | xargs)
yum-config-manager $(xargs -n1 -I{} echo "--enable $([ -f $RPM_CACHE_REPO ] && echo 'cache-'){}" <<<$@ | xargs)
sync
