# ================================================================
# YUM Configuration
# ================================================================

[ -e $STAGE/repo ] && ( set -xe
    case "$DISTRO_ID" in
    "centos" | "rhel")
        until sudo yum install -y sed yum-{plugin-{fastestmirror,priorities},utils}; do echo 'Retrying'; done

        sudo yum-config-manager --setopt=tsflags= --save
        $IS_CONTAINER || sudo yum-config-manager --setopt=installonly_limit=3 --save

        # Hack to skip repo caching.
        [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ] || export RPM_CACHE_REPO="$ROOT_DIR/non-exist-file"

        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" {base,updates,extras,centosplus}{,-source} base-debuginfo

        until sudo yum install -y bc {core,find,ip}utils curl kernel-headers; do echo 'Retrying'; done

        until sudo yum install -y centos-dotnet-release; do echo 'Retrying'; done
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" dotnet

        until sudo yum install -y epel-release; do echo 'Retrying'; done
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" epel{,-source,-debuginfo}

        until sudo yum install -y yum-axelget; do echo 'Retrying'; done

        until sudo yum install -y centos-release-scl{,-rh}; do echo 'Retrying'; done
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" centos-sclo-{sclo,rh}{,-source,-debuginfo}

        until sudo yum update -y --skip-broken; do echo 'Retrying'; done
        sudo yum update -y || true

        sudo rpm -i "$(
            curl -s https://developer.nvidia.com/cuda-downloads                     \
            | grep 'Linux/x86_64/CentOS/7/rpm (network)'                            \
            | head -n1                                                              \
            | sed "s/.*\('.*developer.download.nvidia.com\/[^\']*\.rpm'\).*/\1/"
        )" || true
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" cuda

        # until sudo yum install -y 'https://developer.download.nvidia.com/compute/machine-learning/repos/rhel7/x86_64/nvidia-machine-learning-repo-rhel7-1.0.0-1.x86_64.rpm'; do echo 'Retrying'; done

        sudo yum-config-manager --add-repo "https://download.docker.com/linux/centos/docker-ce.repo"
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" docker-ce-stable{,-source,-debuginfo}

        curl -sSL "https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.rpm.sh" | sudo bash
        RPM_PRIORITY=2 "$ROOT_DIR/apply_cache.sh" runner_gitlab-ci-multi-runner{,-source}

        sudo rm -rvf /etc/yum.repos.d/gitlab_gitlab-ce.repo
        curl -sSL "https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh" | sudo bash
        RPM_PRIORITY=2 "$ROOT_DIR/apply_cache.sh" gitlab_gitlab-ce{,-source}

        until sudo yum install -y bc ping pv which; do echo 'Retrying'; done

        until sudo yum update -y --skip-broken; do echo 'Retrying'; done
        sudo yum update -y || true
        ;;
    "debian" | "linuxmint" | "ubuntu")
        sudo apt-get update -y
        sudo apt-get upgrade -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
            apt-{file,transport-https,utils} \
            ca-certificates \
            coreutils \
            curl \
            gnupg-agent \
            software-properties-common

        (
            set -xe
            cd "$SCRATCH"

            cuda_repo="https://developer.download.nvidia.com/compute/cuda/repos"
            cuda_repo="$cuda_repo/$(curl -sSL "$cuda_repo" | sed -n "s/.*href='\(ubuntu$(sed 's/\.//g' <<< "$DISTRO_VERSION_ID")[[^']*\)\/.*/\1/p" | sort -V | tail -n1)/x86_64"
            sudo apt-key adv --fetch-keys "$cuda_repo/$(curl -sSL "$cuda_repo" | sed -n "s/.*href='\([^']*\.pub\).*/\1/p" | sort -V | tail -n1)"
            cuda_repo="$cuda_repo/$(curl -sSL "$cuda_repo" | sed -n "s/.*href='\(cuda-repo-[^']*\).*/\1/p" | sort -V | tail -n1)"
            nvml_repo="https://developer.download.nvidia.com/compute/machine-learning/repos"
            nvml_repo="$nvml_repo/$(curl -sSL "$nvml_repo" | sed -n "s/.*href='\(ubuntu$(sed 's/\.//g' <<< "$DISTRO_VERSION_ID")[^']*\)\/.*/\1/p" | sort -V | tail -n1)/x86_64"
            nvml_repo="$nvml_repo/$(curl -sSL "$nvml_repo" | sed -n "s/.*href='\(nvidia-machine-learning-repo-[^']*\).*/\1/p" | sort -V | tail -n1)"
            curl -SL "$cuda_repo" > "$(basename "$cuda_repo")"
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "./$(basename "$cuda_repo")"
            rm -rf "$(basename "$cuda_repo")"
            curl -SL "$nvml_repo" > "$(basename "$nvml_repo")"
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "./$(basename "$nvml_repo")"
            rm -rf "$(basename "$nvml_repo")"
        )

        curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt-get update -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
        ;;
    *)
        echo "Unsupported distro \"$DISTRO_ID\"."
        exit 1
        ;;
    esac
)
sudo rm -rvf $STAGE/repo
sync || true
