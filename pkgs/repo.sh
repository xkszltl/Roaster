# ================================================================
# YUM Configuration
# ================================================================

[ -e $STAGE/repo ] && ( set -e
    until yum install -y sed yum-utils; do echo 'Retrying'; done

    yum-config-manager --setopt=tsflags= --save

    $ROOT_DIR/apply_cache.sh {base,updates,extras,centosplus}{,-source} base-debuginfo

    until yum install -y yum-plugin-{priorities,fastestmirror} bc {core,find,ip}utils curl kernel-headers; do echo 'Retrying'; done

    until yum install -y epel-release; do echo 'Retrying'; done
    $ROOT_DIR/apply_cache.sh epel{,-source,-debuginfo}

    until yum install -y yum-axelget; do echo 'Retrying'; done

    until yum install -y centos-release-scl{,-rh}; do echo 'Retrying'; done
    $ROOT_DIR/apply_cache.sh centos-sclo-{sclo,rh}{,-source,-debuginfo}

    until yum update -y --skip-broken; do echo 'Retrying'; done
    yum update -y || true

    rpm -i $(
        curl -s https://developer.nvidia.com/cuda-downloads                     \
        | grep 'Linux/x86_64/CentOS/7/rpm (network)'                            \
        | head -n1                                                              \
        | sed "s/.*\('.*developer.download.nvidia.com\/[^\']*\.rpm'\).*/\1/"
    ) || true
    $ROOT_DIR/apply_cache.sh cuda

    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    $ROOT_DIR/apply_cache.sh docker-ce-stable{,-source,-debuginfo}

    curl -sSL https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.rpm.sh | bash
    $ROOT_DIR/apply_cache.sh runner_gitlab-ci-multi-runner{,-source}

    rm -rvf /etc/yum.repos.d/gitlab_gitlab-ce.repo
    curl -sSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | bash
    $ROOT_DIR/apply_cache.sh gitlab_gitlab-ce{,-source}

    until yum install -y bc ping pv which; do echo 'Retrying'; done

    until yum update -y --skip-broken; do echo 'Retrying'; done
    yum update -y || true
)
rm -rvf $STAGE/repo
sync || true
