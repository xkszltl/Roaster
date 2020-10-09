# ================================================================
# YUM Configuration
# ================================================================

[ -e $STAGE/repo ] && ( set -xe
    case "$DISTRO_ID" in
    "centos" | "rhel")
        until sudo yum makecache -y; do echo 'Retrying'; done
        until sudo yum install -y sed yum-{plugin-{fastestmirror,priorities},utils}; do echo 'Retrying'; done

        sudo yum-config-manager --save --setopt=tsflags=
        $IS_CONTAINER || sudo yum-config-manager --save --setopt=installonly_limit=3

        # Hack to skip repo caching.
        [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ] || export RPM_CACHE_REPO="$ROOT_DIR/non-exist-file"

        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" {base,updates,extras,centosplus}{,-source} base-debuginfo

        until sudo yum install -y nextgen-yum4 dnf-plugins-core; do echo 'Retrying'; done
        sudo dnf config-manager --save --setopt=fastestmirror=true

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

        until sudo dnf config-manager --add-repo "https://developer.download.nvidia.com/compute/cuda/repos/rhel$DISTRO_VERSION_ID/x86_64/cuda-rhel$DISTRO_VERSION_ID.repo"; do echo "Retrying"; done
        sudo sed -i 's/http:\/\//https:\/\//' "/etc/yum.repos.d/cuda-rhel$DISTRO_VERSION_ID.repo"
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" "cuda-rhel$DISTRO_VERSION_ID-$(uname -i)"

        (
            set -xe

            nvml_repo="https://developer.download.nvidia.com/compute/machine-learning/repos"
            nvml_repo="$nvml_repo/$(set -xe && curl -sSLv --retry 100 --retry-delay 5 "$nvml_repo" | sed -n "s/.*href='\($(sed 's/\.//g' <<< "rhel$DISTRO_VERSION_ID")[^']*\)\/.*/\1/p" | sort -V | tail -n1)/x86_64"
            nvml_repo="$nvml_repo/$(set -xe && curl -sSLv --retry 100 --retry-delay 5 "$nvml_repo" | sed -n "s/.*href='\(nvidia-machine-learning-repo-[^']*\).*/\1/p" | sort -V | tail -n1)"
            until sudo dnf install -y "$nvml_repo"; do echo "Retrying"; done
        )
        sudo sed -i 's/http:\/\//https:\/\//' '/etc/yum.repos.d/nvidia-machine-learning.repo'
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" nvidia-machine-learning

        sudo dnf config-manager --add-repo "https://download.docker.com/linux/centos/docker-ce.repo"
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" docker-ce-stable{,-source,-debuginfo}

        sudo dnf config-manager --add-repo "https://nvidia.github.io/nvidia-docker/$DISTRO_ID$DISTRO_VERSION_ID/nvidia-docker.repo"
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

        for retry in $(seq 20 -1 0); do
            [ "$retry" -gt 0 ]
            (
                set -xe
                cd "$SCRATCH"

                rm -rf 'cuda_repo'
                mkdir -p 'cuda_repo'
                cd 'cuda_repo'
                cuda_repo="https://developer.download.nvidia.com/compute/cuda/repos"
                until [ "$cuda_repo_file_dist" ]; do cuda_repo_file_dist="$(set -xe && curl -sSLv --retry 100 --retry-delay 5 "$cuda_repo" | sed -n "s/.*href='\($(sed 's/\.//g' <<< "$DISTRO_ID$DISTRO_VERSION_ID")[^']*\)\/.*/\1/p" | sort -V | tail -n1)"; done
                cuda_repo="$cuda_repo/$cuda_repo_file_dist/x86_64"
                until [ "$cuda_repo_file_pin" ]; do cuda_repo_file_pin="$(set -xe && curl -sSLv --retry 100 --retry-delay 5 "$cuda_repo" | sed -n "s/.*href='\(cuda-$DISTRO_ID$(sed 's/\.//g' <<< "$DISTRO_VERSION_ID")[^']*\.pin\).*/\1/p" | sort -V | tail -n1)"; done
                cuda_repo_pin="$cuda_repo/$cuda_repo_file_pin"
                curl -sSLv --retry 100 --retry-delay 5 "$cuda_repo_pin" | sudo tee '/etc/apt/preferences.d/cuda-repository-pin-600'
                sudo apt-key adv --fetch-keys "$cuda_repo/$(set -xe && curl -sSLv --retry 100 --retry-delay 5 "$cuda_repo" | sed -n "s/.*href='\([^']*\.pub\).*/\1/p" | sort -V | tail -n1)"
                until sudo add-apt-repository "deb $cuda_repo/ /"; do echo "Retrying"; done
            ) && break
            echo "Retry. $(expr "$retry" - 1) time(s) left."
        done

        for retry in $(seq 20 -1 0); do
            [ "$retry" -gt 0 ]
            (
                set -xe
                cd "$SCRATCH"

                rm -rf 'nvml_repo'
                mkdir -p 'nvml_repo'
                cd 'nvml_repo'
                nvml_repo="https://developer.download.nvidia.com/compute/machine-learning/repos"
                until [ "$nvml_repo_file_dist" ]; do nvml_repo_file_dist="$(set -xe && curl -sSLv --retry 100 --retry-delay 5 "$nvml_repo" | sed -n "s/.*href='\($(sed 's/\.//g' <<< "$DISTRO_ID$DISTRO_VERSION_ID")[^']*\)\/.*/\1/p" | sort -V | tail -n1)"; done
                nvml_repo="$nvml_repo/$nvml_repo_file_dist/x86_64"
                until [ "$nvml_repo_file_repo" ]; do nvml_repo_file_repo="$(set -xe && curl -sSLv --retry 100 --retry-delay 5 "$nvml_repo" | sed -n "s/.*href='\(nvidia-machine-learning-repo-[^']*\).*/\1/p" | sort -V | tail -n1)"; done
                nvml_repo="$nvml_repo/$nvml_repo_file_repo"
                curl -SLv --retry 100 --retry-delay 5 "$nvml_repo" > "$(basename "$nvml_repo")"
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "./$(basename "$nvml_repo")"
                rm -rf "$(basename "$nvml_repo")"
                sudo sed -i 's/http:\/\//https:\/\//' '/etc/apt/sources.list.d/nvidia-machine-learning.list'
            ) && break
            echo "Retry. $(expr "$retry" - 1) time(s) left."
        done

        curl -sSL --retry 5 "https://download.docker.com/linux/$DISTRO_ID/gpg" | sudo apt-key add -
        until sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$DISTRO_ID $(lsb_release -cs) stable"; do echo "Retrying"; done
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
