# ================================================================
# YUM Configuration
# ================================================================

[ -e $STAGE/repo ] && ( set -xe
    # Option added in curl 7.52 and not supported by CentOS 7 stock curl 7.29.
    curl_connref="$(! which curl >/dev/null 2>/dev/null || curl --help -v | sed -n 's/.*\(\-\-retry\-connrefused\).*/\1/p' | head -n1)"

    case "$DISTRO_ID" in
    "centos" | "rhel" | 'scientific')
        until sudo yum makecache -y; do echo 'Retrying'; done
        until sudo yum install -y sed yum-{plugin-{fastestmirror,priorities},utils}; do echo 'Retrying'; done

        $IS_CONTAINER || sudo yum-config-manager --save --setopt=installonly_limit=3
        sudo yum-config-manager --save --setopt=tsflags=

        # Hack to skip repo caching.
        [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ] || export RPM_CACHE_REPO="$ROOT_DIR/non-exist-file"

        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" {base,updates,extras,centosplus}{,-source} base-debuginfo

        until sudo yum install -y nextgen-yum4 dnf-plugins-core; do echo 'Retrying'; done
        sudo dnf config-manager --save --setopt=fastestmirror=true
        sudo dnf config-manager --save --setopt=max_parallel_downloads=20
        sudo dnf config-manager --save --setopt=minrate=10k
        sudo dnf config-manager --save --setopt=retries=20

        until sudo dnf makecache -y; do echo 'Retrying'; done
        until sudo dnf install -y bc {core,find,ip}utils curl kernel-headers; do echo 'Retrying'; done
        curl_connref="$(! which curl >/dev/null 2>/dev/null || curl --help -v | sed -n 's/.*\(\-\-retry\-connrefused\).*/\1/p' | head -n1)"

        until sudo dnf install -y centos-release-dotnet; do echo 'Retrying'; done
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" dotnet

        until sudo dnf install -y epel-release; do echo 'Retrying'; done
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" epel{,-source,-debuginfo}

        until sudo dnf install -y yum-axelget; do echo 'Retrying'; done

        until sudo dnf install -y centos-release-scl{,-rh}; do echo 'Retrying'; done
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" centos-sclo-{sclo,rh}{,-source,-debuginfo}

        until sudo dnf update -y; do echo 'Retrying'; done
        sudo dnf update -y || true

        # Known issues:
        #   - Nvidia CDN in China often returns HTTP 200 with error message as content.
        #     The downloaded repo files may contains a single line of "Failed to ssl_handshake: close".
        #     DNF does not check for sanity until it is used.
        for retry in $(seq 100 -1 0); do
            until sudo dnf config-manager --add-repo "https://developer.download.nvidia.com/compute/cuda/repos/rhel$DISTRO_VERSION_ID/x86_64/cuda-rhel$DISTRO_VERSION_ID.repo"; do echo "Retrying"; sleep 1; done
            (
                set -e
                xargs -n1 <<< 'baseurl name' | xargs -I{} grep "^[[:space:]]*{}[[:space:]]*=" "/etc/yum.repos.d/cuda-rhel$DISTRO_VERSION_ID.repo"
                ! grep '[Ff][Aa][Ii][Ll]' "/etc/yum.repos.d/cuda-rhel$DISTRO_VERSION_ID.repo"
                ! grep 'ssl_handshake' "/etc/yum.repos.d/cuda-rhel$DISTRO_VERSION_ID.repo"
            ) && break
            sudo rm -f "/etc/yum.repos.d/cuda-rhel$DISTRO_VERSION_ID.repo"
            echo "Retry. $(expr "$retry" - 1) time(s) left."
            sleep 5
        done
        sudo sed -i 's/http:\/\//https:\/\//' "/etc/yum.repos.d/cuda-rhel$DISTRO_VERSION_ID.repo"
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" "cuda-rhel$DISTRO_VERSION_ID-$(uname -m)"

        (
            set -xe

            nvml_repo="https://developer.download.nvidia.com/compute/machine-learning/repos"
            until [ "$nvml_repo_file_dist" ]; do nvml_repo_file_dist="$(set -xe && curl -sSLv --retry 100 $curl_connref --retry-delay 5 "$nvml_repo" | sed -n "s/.*href='\($(sed 's/\.//g' <<< "rhel$DISTRO_VERSION_ID")[^']*\)\/.*/\1/p" | sort -V | tail -n1 || sleep 5)"; done
            nvml_repo="$nvml_repo/$nvml_repo_file_dist/x86_64"
            until [ "$nvml_repo_file_repo" ]; do nvml_repo_file_repo="$(set -xe && curl -sSLv --retry 100 $curl_connref --retry-delay 5 "$nvml_repo" | sed -n "s/.*href='\(nvidia-machine-learning-repo-[^']*\).*/\1/p" | sort -V | tail -n1 || sleep 5)"; done
            nvml_repo="$nvml_repo/$nvml_repo_file_repo"
            for retry in $(seq 100 -1 0); do
                until sudo dnf install -y "$nvml_repo"; do echo "Retrying"; sleep 1; done
                (
                    set -e
                    xargs -n1 <<< 'baseurl name' | xargs -I{} grep "^[[:space:]]*{}[[:space:]]*=" '/etc/yum.repos.d/nvidia-machine-learning.repo'
                    ! grep '[Ff][Aa][Ii][Ll]' '/etc/yum.repos.d/nvidia-machine-learning.repo'
                    ! grep 'ssl_handshake' '/etc/yum.repos.d/nvidia-machine-learning.repo'
                ) && break
                sudo rm -f '/etc/yum.repos.d/nvidia-machine-learning.repo'
                echo "Retry. $(expr "$retry" - 1) time(s) left."
                sleep 5
            done
        )
        sudo sed -i 's/http:\/\//https:\/\//' '/etc/yum.repos.d/nvidia-machine-learning.repo'
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" nvidia-machine-learning

        # Intel oneAPI.
        sudo dnf config-manager --add-repo "$ROOT_DIR/repos/oneAPI.repo"
        RPM_PRIORITY=2 "$ROOT_DIR/apply_cache.sh" oneAPI

        # Docker-CE.
        sudo dnf config-manager --add-repo "https://download.docker.com/linux/centos/docker-ce.repo"
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" docker-ce-stable{,-source,-debuginfo}

        # Nvidia docker.
        sudo dnf config-manager --add-repo "https://nvidia.github.io/nvidia-docker/$DISTRO_ID$DISTRO_VERSION_ID/nvidia-docker.repo"
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" libnvidia-container nvidia-{container-runtime,docker}

        # GitLab.
        curl -sSL --retry 1000 $curl_connref --retry-delay 1 "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
        RPM_PRIORITY=2 "$ROOT_DIR/apply_cache.sh" runner_gitlab-runner{,-source}

        sudo rm -rvf /etc/yum.repos.d/gitlab_gitlab-ce.repo
        curl -sSL --retry 1000 $curl_connref --retry-delay 1 "https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh" | sudo bash
        RPM_PRIORITY=2 "$ROOT_DIR/apply_cache.sh" gitlab_gitlab-ce{,-source}

        until sudo dnf install -y bc iputils pv which; do echo 'Retrying'; done

        until sudo dnf update -y; do echo 'Retrying'; done
        sudo dnf update -y || true
        ;;
    "debian" | "linuxmint" | "ubuntu")
        sudo apt-get update -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
            apt-{file,transport-https,utils} \
            ca-certificates \
            coreutils \
            curl \
            findutils \
            gnupg-agent \
            software-properties-common
        if [ "_$DISTRO_ID" = '_debian' ]; then
            until sudo add-apt-repository 'contrib'; do echo "Retrying"; sleep 5; done
            until sudo add-apt-repository 'non-free'; do echo "Retrying"; sleep 5; done
        else
            until sudo add-apt-repository 'multiverse'; do echo "Retrying"; sleep 5; done
        fi
        if [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ] && [ -e "$ROOT_DIR/repos/codingcafe-mirror-$DISTRO_ID.list" ]; then
            sudo mkdir -p '/etc/apt/sources.list.d'
            cat "$ROOT_DIR/repos/codingcafe-mirror-$DISTRO_ID.list"    \
            | sed 's/^\(.*\)/printf "%s\\n" "\1"/'  \
            | bash                                  \
            | sudo tee "/etc/apt/sources.list.d/codingcafe-mirror-$DISTRO_ID.list"
            sudo cp -f '/etc/apt/sources.list'{,.bak}
            printf '%s\0' "$DISTRO_VERSION_CODENAME"{,-{backports,security,updates}}                                                                                \
            | sed 's/\([\\\/\.\-]\)/\\\1/g'                                                                                                                         \
            | xargs -0rI{} printf '%s%s%s\n' 's/^\([[:space:]]*deb\)\(\-src\)*\([[:space:]][[:space:]]*[^[:space:]#][^#]*[[:space:]]' {} '[[:space:]]\)/# \1\2\3/'  \
            | paste -sd';' -                                                                                                                                        \
            | xargs -0rI{} sed {} '/etc/apt/sources.list.bak'                                                                                                        \
            | sudo tee '/etc/apt/sources.list'
        fi
        sudo apt-get update -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
        curl_connref="$(! which curl >/dev/null 2>/dev/null || curl --help -v | sed -n 's/.*\(\-\-retry\-connrefused\).*/\1/p' | head -n1)"

        for retry in $(seq 20 -1 0); do
            [ "$retry" -gt 0 ]
            (
                set -xe
                cd "$SCRATCH"

                rm -rf 'cuda_repo'
                mkdir -p 'cuda_repo'
                cd 'cuda_repo'
                cuda_repo="https://developer.download.nvidia.com/compute/cuda/repos"
                until [ "$cuda_repo_file_dist" ]; do cuda_repo_file_dist="$(set -xe && curl -sSLv --retry 100 $curl_connref --retry-delay 5 "$cuda_repo" | sed -n "s/.*href='\($(sed 's/\.//g' <<< "$DISTRO_ID$DISTRO_VERSION_ID")[^']*\)\/.*/\1/p" | sort -V | tail -n1 || sleep 5)"; done
                cuda_repo="$cuda_repo/$cuda_repo_file_dist/x86_64"
                if [ "_$DISTRO_ID" != '_debian' ]; then
                    until [ "$cuda_repo_file_pin" ]; do cuda_repo_file_pin="$(set -xe && curl -sSLv --retry 100 $curl_connref --retry-delay 5 "$cuda_repo" | sed -n "s/.*href='\(cuda-$DISTRO_ID$(sed 's/\.//g' <<< "$DISTRO_VERSION_ID")[^']*\.pin\).*/\1/p" | sort -V | tail -n1 || sleep 5)"; done
                    cuda_repo_pin="$cuda_repo/$cuda_repo_file_pin"
                    curl -sSLv --retry 100 $curl_connref --retry-delay 5 "$cuda_repo_pin" | sudo tee '/etc/apt/preferences.d/cuda-repository-pin-600'
                fi
                until [ "$cuda_repo_file_pubkey" ]; do cuda_repo_file_pubkey="$(set -xe && curl -sSLv --retry 100 $curl_connref --retry-delay 5 "$cuda_repo" | sed -n "s/.*href='\([^']*\.pub\).*/\1/p" | sort -V | tail -n1)"; done
                cuda_repo_pubkey="$cuda_repo/$cuda_repo_file_pubkey"
                # Known issues:
                #   - "apt-key adv --fetch-keys" does not exit with non-zero code on network error.
                # sudo APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key adv --fetch-keys "$cuda_repo_pubkey"
                curl -sSLv --retry 100 $curl_connref --retry-delay 5 "$cuda_repo_pubkey" | sudo apt-key add -
                sudo mkdir -p '/etc/apt/sources.list.d'
                echo "deb $cuda_repo/ /" | sudo tee '/etc/apt/sources.list.d/cuda.list'
                sudo apt-get update -y
            ) && break
            echo "Retry. $(expr "$retry" - 1) time(s) left."
            sleep 5
        done
        [ "_$GIT_MIRROR" != "_$GIT_MIRROR_CODINGCAFE" ] || "$ROOT_DIR/apply_cache.sh" cuda
        sudo apt-get update -y

        for retry in $(seq 20 -1 0); do
            [ "_$DISTRO_ID" != '_debian' ] || break
            [ "$retry" -gt 0 ]
            (
                set -xe
                cd "$SCRATCH"

                rm -rf 'nvml_repo'
                mkdir -p 'nvml_repo'
                cd 'nvml_repo'
                nvml_repo="https://developer.download.nvidia.com/compute/machine-learning/repos"
                until [ "$nvml_repo_file_dist" ]; do nvml_repo_file_dist="$(set -xe && curl -sSLv --retry 100 $curl_connref --retry-delay 5 "$nvml_repo" | sed -n "s/.*href='\($(sed 's/\.//g' <<< "$DISTRO_ID$DISTRO_VERSION_ID")[^']*\)\/.*/\1/p" | sort -V | tail -n1 || sleep 5)"; done
                nvml_repo="$nvml_repo/$nvml_repo_file_dist/x86_64"
                until [ "$nvml_repo_file_repo" ]; do nvml_repo_file_repo="$(set -xe && curl -sSLv --retry 100 $curl_connref --retry-delay 5 "$nvml_repo" | sed -n "s/.*href='\(nvidia-machine-learning-repo-[^']*\).*/\1/p" | sort -V | tail -n1 || sleep 5)"; done
                nvml_repo="$nvml_repo/$nvml_repo_file_repo"
                curl -SLv --retry 100 $curl_connref --retry-delay 5 "$nvml_repo" > "$(basename "$nvml_repo")"
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "./$(basename "$nvml_repo")"
                rm -rf "$(basename "$nvml_repo")"
                sudo sed -i 's/http:\/\//https:\/\//' '/etc/apt/sources.list.d/nvidia-machine-learning.list'
            ) && break
            echo "Retry. $(expr "$retry" - 1) time(s) left."
            sleep 5
        done

        # Intel oneAPI.
        curl -sSL --retry 10000 $curl_connref --retry-delay 1 "https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB" | sudo APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add -
        sudo mkdir -p '/etc/apt/sources.list.d'
        sudo cp -f "$ROOT_DIR/repos/intel-oneapi.list" '/etc/apt/sources.list.d/'
        [ "_$GIT_MIRROR" != "_$GIT_MIRROR_CODINGCAFE" ] || "$ROOT_DIR/apply_cache.sh" intel-oneapi
        sudo apt-get update -y

        # Docker-CE.
        curl -sSL --retry 10000 $curl_connref --retry-delay 1 "https://download.docker.com/linux/$DISTRO_ID/gpg" | sudo APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add -
        sudo mkdir -p '/etc/apt/sources.list.d'
        cat "$ROOT_DIR/repos/docker-ce.list"    \
        | sed 's/^\(.*\)/printf "%s\\n" "\1"/'  \
        | bash                                  \
        | sudo tee "/etc/apt/sources.list.d/docker-ce.list"
        [ "_$GIT_MIRROR" != "_$GIT_MIRROR_CODINGCAFE" ] || "$ROOT_DIR/apply_cache.sh" docker-ce
        sudo apt-get update -y

        # Nvidia docker.
        curl -sSL --retry 1000 $curl_connref --retry-delay 1 "https://nvidia.github.io/nvidia-docker/gpgkey" | sudo APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add -
        curl -sSL --retry 1000 $curl_connref --retry-delay 1 "https://nvidia.github.io/nvidia-docker/$DISTRO_ID$DISTRO_VERSION_ID/nvidia-docker.list" | sudo tee "/etc/apt/sources.list.d/nvidia-docker.list"

        sudo apt-get update -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

        echo '-----------------------------------------------------------------'
        echo '| Active repos'
        echo '-----------------------------------------------------------------'
        sed 's/#.*//' '/etc/apt/sources.list'{,.d/*.list} | grep '[^[:space:]]' | sed 's/^/| /'
        echo '-----------------------------------------------------------------'
        ;;
    *)
        echo "Unsupported distro \"$DISTRO_ID\"."
        exit 1
        ;;
    esac
)
sudo rm -rvf $STAGE/repo
sync || true
