# ================================================================
# YUM Configuration
# ================================================================

[ -e $STAGE/repo ] && ( set -xe
    # Multiple detection logic:
    # - Option added in curl 7.52 and not supported by CentOS 7 stock curl 7.29.
    # - Help menu was folded somewhere between curl 7.68 and 7.74.
    #
    # Note it may be reset below after installing curl.
    curl_connref="$(! which curl >/dev/null 2>/dev/null || curl --help -v | sed -n 's/.*\(\-\-retry\-connrefused\).*/\1/p' | head -n1 | grep . || curl --help curl | sed -n 's/.*\(\-\-retry\-connrefused\).*/\1/p' | head -n1)"

    case "$DISTRO_ID" in
    'centos' | 'rhel' | 'scientific')
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
        curl_connref="$(! which curl >/dev/null 2>/dev/null || curl --help -v | sed -n 's/.*\(\-\-retry\-connrefused\).*/\1/p' | head -n1 | grep . || curl --help curl | sed -n 's/.*\(\-\-retry\-connrefused\).*/\1/p' | head -n1)"

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

        case "$DISTRO_ID-$DISTRO_VERSION_ID" in
        'centos-7' | 'centos-8' | 'rhel-7' | 'rhel-8' | 'scientific-'*)
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
            ;;
        esac

        # Intel oneAPI.
        sudo dnf config-manager --add-repo "$ROOT_DIR/repos/oneAPI.repo"
        RPM_PRIORITY=2 "$ROOT_DIR/apply_cache.sh" oneAPI

        # Docker-CE.
        sudo dnf config-manager --add-repo "https://download.docker.com/linux/centos/docker-ce.repo"
        RPM_PRIORITY=1 "$ROOT_DIR/apply_cache.sh" docker-ce-stable{,-source,-debuginfo}

        # Nvidia docker.
        # Note:
        #     Repo for Ubuntu 20.04/22.04 may reuse 18.04 URL according to official doc.
        #     This is not a bug.
        #     - https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#docker
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
    'debian' | 'linuxmint' | 'ubuntu')
        sudo apt-get -o 'DPkg::Lock::Timeout=3600' update -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get -o 'DPkg::Lock::Timeout=3600' upgrade -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get -o 'DPkg::Lock::Timeout=3600' install -y    \
            apt-{file,transport-https,utils} \
            ca-certificates \
            coreutils \
            curl \
            findutils \
            gnupg-agent \
            software-properties-common
        if [ "_$DISTRO_ID" = '_debian' ]; then
            until sudo add-apt-repository -y 'contrib'; do echo "Retrying"; sleep 5; done
            until sudo add-apt-repository -y 'non-free'; do echo "Retrying"; sleep 5; done
        else
            until sudo add-apt-repository -y 'multiverse'; do echo "Retrying"; sleep 5; done
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
        sudo apt-get -o 'DPkg::Lock::Timeout=3600' update -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get -o 'DPkg::Lock::Timeout=3600' upgrade -y
        curl_connref="$(! which curl >/dev/null 2>/dev/null || curl --help -v | sed -n 's/.*\(\-\-retry\-connrefused\).*/\1/p' | head -n1 | grep . || curl --help curl | sed -n 's/.*\(\-\-retry\-connrefused\).*/\1/p' | head -n1)"

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
                case "$DISTRO_ID-$DISTRO_VERSION_ID" in
                'ubuntu-'*)
                    until [ "$cuda_repo_file_pin" ]; do cuda_repo_file_pin="$(set -xe && curl -sSLv --retry 100 $curl_connref --retry-delay 5 "$cuda_repo" | sed -n "s/.*href='\(cuda-$DISTRO_ID$(sed 's/\.//g' <<< "$DISTRO_VERSION_ID")[^']*\.pin\).*/\1/p" | sort -V | tail -n1 || sleep 5)"; done
                    cuda_repo_pin="$cuda_repo/$cuda_repo_file_pin"
                    curl -sSLv --retry 100 $curl_connref --retry-delay 5 "$cuda_repo_pin" | sudo tee '/etc/apt/preferences.d/cuda-repository-pin-600'
                    ;;
                esac
                until [ "$cuda_repo_file_pubkey" ]; do cuda_repo_file_pubkey="$(set -xe && curl -sSLv --retry 100 $curl_connref --retry-delay 5 "$cuda_repo" | sed -n "s/.*href='\([^']*\.pub\).*/\1/p" | sort -V)"; done
                for file_pubkey in $cuda_repo_file_pubkey; do
                    # Known issues:
                    #   - "apt-key adv --fetch-keys" does not exit with non-zero code on network error.
                    # sudo APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key adv --fetch-keys "$cuda_repo/$file_pubkey"
                    [ -e '/etc/apt/keyrings' ] || ! sudo mkdir -m 755 '/etc/apt/keyrings'
                    curl -sSLv --retry 100 $curl_connref --retry-delay 5 "$cuda_repo/$file_pubkey"  \
                    | sudo tee '/etc/apt/trusted.gpg.d/cuda.asc'                                    \
                    | grep -a .                                                                     \
                    > /dev/null
                done
                sudo mkdir -p '/etc/apt/sources.list.d'
                echo "deb $cuda_repo/ /" | sudo tee '/etc/apt/sources.list.d/cuda.list'
                # Known issues:
                #   - TensorRT/NCCL is not available for Debian 11 as of Oct 2025.
                #     They are only added to Debian 12 in Aug 2025.
                #     Try to use the Ubuntu build instead.
                case "$DISTRO_ID-$DISTRO_VERSION_ID" in
                'debian-11')
                    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/$(uname -m)/ /" | sudo tee -a '/etc/apt/sources.list.d/cuda.list'
                    printf 'Package: *\nPin: origin developer.download.nvidia.com/compute/cuda/repos/ubuntu2004\nPin-Priority: 1\n' | sudo tee '/etc/apt/preferences.d/99-cuda'
                    ;;
                esac
                sudo apt-get -o 'DPkg::Lock::Timeout=3600' update -y
            ) && break
            echo "Retry. $(expr "$retry" - 1) time(s) left."
            sleep 5
        done
        [ "_$GIT_MIRROR" != "_$GIT_MIRROR_CODINGCAFE" ] || "$ROOT_DIR/apply_cache.sh" cuda
        sudo apt-get -o 'DPkg::Lock::Timeout=3600' update -y

        case "$DISTRO_ID-$DISTRO_VERSION_ID" in
        'ubuntu-14.04' | 'ubuntu-16.04' | 'ubuntu-18.04' | 'ubuntu-20.04')
            for retry in $(seq 20 -1 0); do
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
                    sudo DEBIAN_FRONTEND=noninteractive apt-get -o 'DPkg::Lock::Timeout=3600' install -y "./$(basename "$nvml_repo")"
                    rm -rf "$(basename "$nvml_repo")"
                    sudo sed -i 's/http:\/\//https:\/\//' '/etc/apt/sources.list.d/nvidia-machine-learning.list'
                ) && break
                echo "Retry. $(expr "$retry" - 1) time(s) left."
                sleep 5
            done
            ;;
        esac

        # Intel oneAPI.
        [ -e '/etc/apt/keyrings' ] || ! sudo mkdir -m 755 '/etc/apt/keyrings'
        curl -sSL --retry 10000 $curl_connref --retry-delay 1 "https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB"    \
        | sudo tee '/etc/apt/keyrings/oneapi-archive-keyring.asc'                                                                               \
        | grep -a .                                                                                                                             \
        > /dev/null
        sudo mkdir -p '/etc/apt/sources.list.d'
        sudo cp -f "$ROOT_DIR/repos/intel-oneapi.list" '/etc/apt/sources.list.d/'
        [ "_$GIT_MIRROR" != "_$GIT_MIRROR_CODINGCAFE" ] || "$ROOT_DIR/apply_cache.sh" intel-oneapi
        sudo apt-get -o 'DPkg::Lock::Timeout=3600' update -y

        # Docker-CE.
        [ -e '/etc/apt/keyrings' ] || ! sudo mkdir -m 755 '/etc/apt/keyrings'
        curl -sSL --retry 10000 $curl_connref --retry-delay 1 "https://download.docker.com/linux/$DISTRO_ID/gpg"    \
        | sudo tee '/etc/apt/keyrings/docker.asc'                                                                   \
        | grep -a .                                                                                                 \
        > /dev/null
        sudo mkdir -p '/etc/apt/sources.list.d'
        cat "$ROOT_DIR/repos/docker-ce.list"    \
        | sed 's/^\(.*\)/printf "%s\\n" "\1"/'  \
        | bash                                  \
        | sudo tee "/etc/apt/sources.list.d/docker-ce.list"
        [ "_$GIT_MIRROR" != "_$GIT_MIRROR_CODINGCAFE" ] || "$ROOT_DIR/apply_cache.sh" docker-ce
        sudo apt-get -o 'DPkg::Lock::Timeout=3600' update -y

        # Nvidia container toolkit.
        # Known issue:
        # - Hide SNI with manual resolution if necessary, at the cost of unverified cert.
        [ -e '/etc/apt/keyrings' ] || ! sudo mkdir -m 755 '/etc/apt/keyrings'
        (
            set -e
            ! curl -sSL --retry 1000 $curl_connref --retry-delay 1 "https://nvidia.github.io/libnvidia-container/gpgkey" || exit 0
            printf '\033[33m[WARNING] Fallback to hidden SNI when fetching nvidia-container-toolkit GPG key. Beware of security risk from unverified cert.\033[0m\n' >&2
            ! curl -sSL --retry 1000 $curl_connref --retry-delay 1 -kH "Host: nvidia.github.io" "https://$(set -e
                    curl -svX HEAD "https://nvidia.github.io" 2>&1 >/dev/null                               \
                    | sed -n 's/.*Trying \([1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*\):443.*/\1/p' \
                    | head -n1                                                                              \
                    | grep .
                )/libnvidia-container/gpgkey" \
            || exit 0
            printf '\033[31m[ERROR] Failed to get nvidia-container-toolkit GPG key.\033[0m\n' >&2
            exit 1
        )                                                                   \
        | sudo tee '/etc/apt/keyrings/nvidia-container-toolkit-keyring.asc' \
        | grep -a .                                                         \
        > /dev/null
        (
            set -e
            ! curl -sSL --retry 1000 $curl_connref --retry-delay 1 "https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list" || exit 0
            printf '\033[33m[WARNING] Fallback to hidden SNI when fetching nvidia-container-toolkit repo config. Beware of security risk from unverified cert.\033[0m\n' >&2
            ! curl -sSL --retry 1000 $curl_connref --retry-delay 1 -kH "Host: nvidia.github.io" "https://$(set -e
                    curl -svX HEAD "https://nvidia.github.io" 2>&1 >/dev/null                               \
                    | sed -n 's/.*Trying \([1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*\):443.*/\1/p' \
                    | head -n1                                                                              \
                    | grep .
                )/libnvidia-container/stable/deb/nvidia-container-toolkit.list"    \
            || exit 0
            printf '\033[31m[ERROR] Failed to get nvidia-container-toolkit repo config.\033[0m\n' >&2
            exit 1
        ) | sudo tee '/etc/apt/sources.list.d/nvidia-container-toolkit.list'
        sudo sed -i 's/\(deb[[:space:]]\)\([[:space:]]*http\)/\1\[signed-by=\/etc\/apt\/keyrings\/nvidia\-container\-toolkit\-keyring\.asc\] \2/' '/etc/apt/sources.list.d/nvidia-container-toolkit.list'

        sudo apt-get -o 'DPkg::Lock::Timeout=3600' update -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get -o 'DPkg::Lock::Timeout=3600' upgrade -y

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
sync "$STAGE" || true
