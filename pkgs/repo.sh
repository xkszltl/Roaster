# ================================================================
# YUM Configuration
# ================================================================

[ -e $STAGE/repo ] && ( set -xe
    until sudo yum install -y sed yum-utils; do echo 'Retrying'; done

    sudo yum-config-manager --setopt=tsflags= --save
    $IS_CONTAINER || sudo yum-config-manager --setopt=installonly_limit=3 --save

    [ "_$GIT_MIRROR" == "_$GIT_MIRROR_CODINGCAFE" ] && $ROOT_DIR/apply_cache.sh {base,updates,extras,centosplus}{,-source} base-debuginfo

    until sudo yum install -y yum-plugin-{priorities,fastestmirror} bc {core,find,ip}utils curl kernel-headers; do echo 'Retrying'; done

    until sudo yum install -y epel-release; do echo 'Retrying'; done
    [ "_$GIT_MIRROR" == "_$GIT_MIRROR_CODINGCAFE" ] && $ROOT_DIR/apply_cache.sh epel{,-source,-debuginfo}

    until sudo yum install -y yum-axelget; do echo 'Retrying'; done

    until sudo yum install -y centos-release-scl{,-rh}; do echo 'Retrying'; done
    [ "_$GIT_MIRROR" == "_$GIT_MIRROR_CODINGCAFE" ] && $ROOT_DIR/apply_cache.sh centos-sclo-{sclo,rh}{,-source,-debuginfo}

    until sudo yum update -y --skip-broken; do echo 'Retrying'; done
    sudo yum update -y || true

    sudo rpm -i $(
        curl -s https://developer.nvidia.com/cuda-downloads                     \
        | grep 'Linux/x86_64/CentOS/7/rpm (network)'                            \
        | head -n1                                                              \
        | sed "s/.*\('.*developer.download.nvidia.com\/[^\']*\.rpm'\).*/\1/"
    ) || true
    [ "_$GIT_MIRROR == "_$GIT_MIRROR_CODINGCAFE" ] && $ROOT_DIR/apply_cache.sh cuda

    until sudo yum install -y 'https://developer.download.nvidia.com/compute/machine-learning/repos/rhel7/x86_64/nvidia-machine-learning-repo-rhel7-1.0.0-1.x86_64.rpm'; do echo 'Retrying'; done
    [ "_$GIT_MIRROR" == "_$GIT_MIRROR_CODINGCAFE" ] && $ROOT_DIR/apply_cache.sh nccl

    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    [ "_$GIT_MIRROR" == "_$GIT_MIRROR_CODINGCAFE" ] && $ROOT_DIR/apply_cache.sh docker-ce-stable{,-source,-debuginfo}

    curl -sSL https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.rpm.sh | sudo bash
    [ "_$GIT_MIRROR" == "_$GIT_MIRROR_CODINGCAFE" ] && $ROOT_DIR/apply_cache.sh runner_gitlab-ci-multi-runner{,-source}

    sudo rm -rvf /etc/yum.repos.d/gitlab_gitlab-ce.repo
    curl -sSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
    [ "_$GIT_MIRROR" == "_$GIT_MIRROR_CODINGCAFE" ] && $ROOT_DIR/apply_cache.sh gitlab_gitlab-ce{,-source}

    until sudo yum install -y bc ping pv which; do echo 'Retrying'; done

    until sudo yum update -y --skip-broken; do echo 'Retrying'; done
    sudo yum update -y || true
)
sudo rm -rvf $STAGE/repo
sync || true
