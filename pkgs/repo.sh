# ================================================================
# YUM Configuration
# ================================================================

[ -e $STAGE/repo ] && ( set -xe
    case "$DISTRO_ID" in
    "centos" | "rhel")
        until sudo yum makecache -y; do echo 'Retrying'; done
        until sudo yum install -y sed yum-{plugin-{fastestmirror,priorities},utils}; do echo 'Retrying'; done

        sudo yum-config-manager --setopt=tsflags= --save
        $IS_CONTAINER || sudo yum-config-manager --setopt=installonly_limit=3 --save

        # Hack to skip repo caching.
        [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ] || export RPM_CACHE_REPO="$ROOT_DIR/non-exist-file"

        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" {base,updates,extras,centosplus}{,-source} base-debuginfo

        until sudo yum install -y nextgen-yum4 dnf-plugins-core; do echo 'Retrying'; done

        until sudo dnf makecache -y; do echo 'Retrying'; done
        until sudo dnf install -y bc {core,find,ip}utils curl kernel-headers; do echo 'Retrying'; done

        until sudo dnf install -y centos-release-dotnet; do echo 'Retrying'; done
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" dotnet

        until sudo dnf install -y epel-release; do echo 'Retrying'; done
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" epel{,-source,-debuginfo}

        until sudo dnf install -y yum-axelget; do echo 'Retrying'; done

        until sudo dnf install -y centos-release-scl{,-rh}; do echo 'Retrying'; done
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" centos-sclo-{sclo,rh}{,-source,-debuginfo}

        until sudo dnf update -y; do echo 'Retrying'; done
        sudo dnf update -y || true

        sudo yum-config-manager --add-repo "https://developer.download.nvidia.com/compute/cuda/repos/rhel$DISTRO_VERSION_ID/x86_64/cuda-rhel$DISTRO_VERSION_ID.repo"
        sudo sed -i 's/http:\/\//https:\/\//' "/etc/yum.repos.d/cuda-rhel$DISTRO_VERSION_ID.repo"
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" cuda

        (
            set -xe

            nvml_repo="https://developer.download.nvidia.com/compute/machine-learning/repos"
            nvml_repo="$nvml_repo/$(curl -sSL --retry 5 "$nvml_repo" | sed -n "s/.*href='\($(sed 's/\.//g' <<< "rhel$DISTRO_VERSION_ID")[^']*\)\/.*/\1/p" | sort -V | tail -n1)/x86_64"
            nvml_repo="$nvml_repo/$(curl -sSL --retry 5 "$nvml_repo" | sed -n "s/.*href='\(nvidia-machine-learning-repo-[^']*\).*/\1/p" | sort -V | tail -n1)"
            sudo dnf install -y "$nvml_repo"
        )
        sudo sed -i 's/http:\/\//https:\/\//' '/etc/yum.repos.d/nvidia-machine-learning.repo'
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" nvidia-machine-learning

        sudo yum-config-manager --add-repo "https://download.docker.com/linux/centos/docker-ce.repo"
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" docker-ce-stable{,-source,-debuginfo}

        sudo yum-config-manager --add-repo "https://nvidia.github.io/nvidia-docker/$DISTRO_ID$DISTRO_VERSION_ID/nvidia-docker.repo"
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" libnvidia-container nvidia-{container-runtime,docker}

        curl -sSL --retry 5 "https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.rpm.sh" | sudo bash
        RPM_PRIORITY=2 "$ROOT_DIR/apply_cache.sh" runner_gitlab-ci-multi-runner{,-source}

        sudo rm -rvf /etc/yum.repos.d/gitlab_gitlab-ce.repo
        curl -sSL --retry 5 "https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh" | sudo bash
        RPM_PRIORITY=2 "$ROOT_DIR/apply_cache.sh" gitlab_gitlab-ce{,-source}

        until sudo dnf install -y bc iputils pv which; do echo 'Retrying'; done

        until sudo dnf update -y; do echo 'Retrying'; done
        sudo dnf update -y || true
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
            cuda_repo="$cuda_repo/$(curl -sSL --retry 5 "$cuda_repo" | sed -n "s/.*href='\($(sed 's/\.//g' <<< "$DISTRO_ID$DISTRO_VERSION_ID")[^']*\)\/.*/\1/p" | sort -V | tail -n1)/x86_64"
            sudo apt-key adv --fetch-keys "$cuda_repo/$(curl -sSL --retry 5 "$cuda_repo" | sed -n "s/.*href='\([^']*\.pub\).*/\1/p" | sort -V | tail -n1)"
            cuda_repo="$cuda_repo/$(curl -sSL --retry 5 "$cuda_repo" | sed -n "s/.*href='\(cuda-repo-[^']*\).*/\1/p" | sort -V | tail -n1)"
            nvml_repo="https://developer.download.nvidia.com/compute/machine-learning/repos"
            nvml_repo="$nvml_repo/$(curl -sSL --retry 5 "$nvml_repo" | sed -n "s/.*href='\($(sed 's/\.//g' <<< "$DISTRO_ID$DISTRO_VERSION_ID")[^']*\)\/.*/\1/p" | sort -V | tail -n1)/x86_64"
            nvml_repo="$nvml_repo/$(curl -sSL --retry 5 "$nvml_repo" | sed -n "s/.*href='\(nvidia-machine-learning-repo-[^']*\).*/\1/p" | sort -V | tail -n1)"
            curl -SL --retry 5 "$cuda_repo" > "$(basename "$cuda_repo")"
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "./$(basename "$cuda_repo")"
            rm -rf "$(basename "$cuda_repo")"
            sudo sed -i 's/http:\/\//https:\/\//' '/etc/apt/sources.list.d/cuda.list'
            curl -SL --retry 5 "$nvml_repo" > "$(basename "$nvml_repo")"
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "./$(basename "$nvml_repo")"
            rm -rf "$(basename "$nvml_repo")"
            sudo sed -i 's/http:\/\//https:\/\//' '/etc/apt/sources.list.d/nvidia-machine-learning.list'
        )

        curl -sSL --retry 5 "https://download.docker.com/linux/$DISTRO_ID/gpg" | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$DISTRO_ID $(lsb_release -cs) stable"
        curl -sSL --retry 5 "https://nvidia.github.io/nvidia-docker/gpgkey" | sudo apt-key add -
        curl -sSL --retry 5 "https://nvidia.github.io/nvidia-docker/$DISTRO_ID$DISTRO_VERSION_ID/nvidia-docker.list" | sudo tee "/etc/apt/sources.list.d/nvidia-docker.list"

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
