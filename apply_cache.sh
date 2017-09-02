#!/bin/bash

set -e
cat $(cd $(dirname $0) && pwd)/cache.repo > /etc/yum.repos.d/cache.repo
echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}{{updates,extras,centosplus,runner_gitlab-ci-multi-runner,gitlab_gitlab-ce}{,-source},{base,epel,centos-sclo-{sclo,rh},docker-ce-stable}{,-source,-debuginfo},cuda}\; | sed 's/%/ /g' | bash
sync
