# ================================================================
# YUM Configuration
# ================================================================

[ -e $STAGE/repo ] && ( set -e
    until yum install -y sed yum-utils; do echo 'Retrying'; done

    yum-config-manager --setopt=tsflags= --save

    [ -f $RPM_CACHE_REPO ] || yum-config-manager --add-repo https://repo.codingcafe.org/cache/el/7/cache.repo

    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}{{base,updates,extras,centosplus}{,-source},base-debuginfo}\; | sed 's/%/ /g' | bash

    until yum install -y yum-plugin-{priorities,fastestmirror} bc {core,find,ip}utils curl kernel-headers; do echo 'Retrying'; done

    until yum install -y epel-release; do echo 'Retrying'; done
    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}epel{,-source,-debuginfo}\; | sed 's/%/ /g' | bash

    until yum install -y yum-axelget; do echo 'Retrying'; done

    until yum install -y centos-release-scl{,-rh}; do echo 'Retrying'; done
    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}centos-sclo-{sclo,rh}{,-source,-debuginfo}\; | sed 's/%/ /g' | bash

    until yum update -y --skip-broken; do echo 'Retrying'; done
    yum update -y || true

    rpm -i $(
        curl -s https://developer.nvidia.com/cuda-downloads                     \
        | grep 'Linux/x86_64/CentOS/7/rpm (network)'                            \
        | head -n1                                                              \
        | sed "s/.*\('.*developer.download.nvidia.com\/[^\']*\.rpm'\).*/\1/"
    ) || true
    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}cuda\; | sed 's/%/ /g' | bash

    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}docker-ce-stable{,-source,-debuginfo}\; | sed 's/%/ /g' | bash

    curl -sSL https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.rpm.sh | bash
    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}runner_gitlab-ci-multi-runner{,-source}\; | sed 's/%/ /g' | bash

    rm -rvf /etc/yum.repos.d/gitlab_gitlab-ce.repo
    curl -sSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | bash
    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}gitlab_gitlab-ce{,-source}\; | sed 's/%/ /g' | bash

    until yum update -y --skip-broken; do echo 'Retrying'; done
    yum update -y || true
) && rm -rvf $STAGE/repo
sync || true
