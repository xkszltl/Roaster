# ================================================================
# Install Extra CUDA Packages
# ================================================================

[ -e $STAGE/cuda ] && ( set -xe
    cd $SCRATCH

    # Need to push nvidia.cn very hard, before we have mirror for Ubuntu.
    case "$DISTRO_ID" in
    'debian' | 'linuxmint' | 'ubuntu')
        DEB_MAX_ATTEMPT=1000
        PKG_MAX_ATTEMPT=1000
        ;;
    esac

    export CUDA_VER_MAJOR="11"
    export CUDA_VER_MINOR="5"
    case "$DISTRO_ID" in
    'centos' | 'fedora' | 'rhel')
        sudo dnf makecache
        for i in 'compat' 'toolkit'; do
            for attempt in $(seq "$RPM_MAX_ATTEMPT" -1 0); do
                [ "$attempt" -gt 0 ]
                dnf list -q "cuda-$i-$CUDA_VER_MAJOR-$CUDA_VER_MINOR"   \
                | sed -n "s/^\(cuda-$i-[0-9\-]*\).*/\1/p"               \
                | sort -Vu                                              \
                | tail -n1                                              \
                | xargs -r $RPM_INSTALL                                 \
                && break
                echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
            done
        done
        ;;
    'debian' | 'linuxmint' | 'ubuntu')
        sudo apt-get update -y
        for i in 'compat' 'toolkit'; do
            for attempt in $(seq "$DEB_MAX_ATTEMPT" -1 0); do
                [ "$attempt" -gt 0 ]
                apt-cache show "cuda-$i-$CUDA_VER_MAJOR-$CUDA_VER_MINOR"            \
                | sed -n 's/^Package:[[:space:]]*\(cuda-\)/\1/p'                    \
                | sort -Vu                                                          \
                | tail -n1                                                          \
                | sudo DEBIAN_FRONTEND=noninteractive xargs -r apt-get install -y   \
                && break
                echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
            done
        done
        # Blacklist
        if false; then
            for attempt in $(seq "$DEB_MAX_ATTEMPT" -1 0); do
                [ "$attempt" -gt 0 ]
                apt-cache show 'cuda'                                           \
                | sed -n 's/^Package:[[:space:]]*cuda-//p'                      \
                | sort -Vu                                                      \
                | tail -n1                                                      \
                | xargs -I{} apt-cache show 'cuda-*-{}'                         \
                | sed -n 's/^Package:[[:space:]]*//p'                           \
                | grep -v '^cuda-demo-suite-'                                   \
                | grep -v '^cuda-runtime-'                                      \
                | paste -s -                                                    \
                | sudo DEBIAN_FRONTEND=noninteractive xargs apt-get install -y  \
                && break
                echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
            done
        fi
        ! dpkg -l cuda-drivers || $IS_CONTAINER
        ;;
    esac

    if $IS_CONTAINER; then
        # Note:
        #   - cuda-toolkit creates symlink "/usr/local/cuda -> /etc/alternatives/cuda -> /usr/local/cuda-<ver>".
        #     libnvidia-container cannot set up cuda-compat driver properly in this case.
        #     Use "ln -T" to overwrite dir symlink.
        #   - Only rel path "/usr/local/cuda -> cuda-<ver>" works for libnvidia-container, not "/usr/local/cuda -> /usr/local/cuda-<ver>".
        #     https://github.com/NVIDIA/libnvidia-container/issues/117
        ls -d "/usr/local/cuda-$CUDA_VER_MAJOR.$CUDA_VER_MINOR/" | sort -V | tail -n1 | xargs -n1 basename | sudo xargs -I{} ln -sfT {} "/usr/local/cuda"
    else
        for attempt in $(seq "$PKG_MAX_ATTEMPT" -1 0); do
            [ "$attempt" -gt 0 ]
            (
                set -e
                case "$DISTRO_ID" in
                'centos' | 'fedora' | 'rhel')
                    $RPM_INSTALL "cuda-$CUDA_VER_MAJOR.$CUDA_VER_MINOR.*" 'nvidia-driver-latest-dkms'
                    $RPM_INSTALL 'cuda-drivers'
                    ;;
                'debian' | 'linuxmint' | 'ubuntu')
                    apt-cache show "cuda-toolkit-$CUDA_VER_MAJRO-$CUDA_VER_MINOR"   \
                    | sed -n 's/^Version:[[:space:]]*//p'                           \
                    | sort -Vu                                                      \
                    | tail -n1                                                      \
                    | xargs -I{} sudo DEBIAN_FRONTEND=noninteractive apt-get install --allow-downgrades -y "cuda={}"
                    ;;
                esac
            ) && break
            echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
        done
    fi

    [ -x '/usr/local/cuda/bin/nvcc' ]
    export CUDA_VER="$(/usr/local/cuda/bin/nvcc --version | sed -n 's/.*[[:space:]]V\([0-9\.]*\).*/\1/p')"
    export CUDA_VER_MAJOR="$(cut -d'.' -f1 <<< "$CUDA_VER")"
    export CUDA_VER_MINOR="$(cut -d'.' -f2 <<< "$CUDA_VER")"
    export CUDA_VER_BUILD="$(cut -d'.' -f3 <<< "$CUDA_VER")"

    # CUDA version re-mapping should be maintained according to the latest release.
    for attempt in $(seq "$PKG_MAX_ATTEMPT" -1 0); do
        [ "$attempt" -gt 0 ]
        (
            set -e
            case "$DISTRO_ID" in
            'centos' | 'fedora' | 'rhel')
                $RPM_INSTALL                                                                                            \
                    libcudnn8{,-devel}"-*-*cuda$CUDA_VER_MAJOR.$CUDA_VER_MINOR"                                         \
                    libnccl{,-devel,-static}"-*-*cuda$(sed 's/11\.[1-3]/11\.0/' <<< "$CUDA_VER_MAJOR.$CUDA_VER_MINOR" | sed 's/11\.[6-9]/11\.4/')"  \
                    libnv{infer{,-plugin},{,onnx}parsers}{8,-devel}"-8.*-*cuda$(sed 's/11\.[12]/11\.0/' <<< "$CUDA_VER_MAJOR.$CUDA_VER_MINOR" | sed 's/11\.[5-9]/11\.4/')"
                : || $RPM_INSTALL                                                                                       \
                    libnv{infer{,-plugin},{,onnx}parsers}{7,-devel}"-7.*-*cuda$(sed 's/11\.[2-4]/11\.1/' <<< "$CUDA_VER_MAJOR.$CUDA_VER_MINOR")"
                ;;
            'debian' | 'linuxmint' | 'ubuntu')
                sudo DEBIAN_FRONTEND=noninteractive apt-get install --allow-downgrades -y                               \
                    libcudnn8{,-dev}"=*+cuda$CUDA_VER_MAJOR.$CUDA_VER_MINOR"                                            \
                    libnccl{2,-dev}"=*+cuda$(sed 's/11\.[1-3]/11\.0/' <<< "$CUDA_VER_MAJOR.$CUDA_VER_MINOR" | sed 's/11\.[6-9]/11\.5/')"            \
                    libnv{infer{,-plugin},{,onnx}parsers}{8,-dev}"=8.*+cuda$(sed 's/11\.[12]/11\.0/' <<< "$CUDA_VER_MAJOR.$CUDA_VER_MINOR" | sed 's/11\.[5-9]/11\.4/')"
                : || sudo DEBIAN_FRONTEND=noninteractive apt-get install --allow-downgrades -y                          \
                    libnv{infer{,-plugin},{,onnx}parsers}{7,-dev}"=7.*+cuda$(sed 's/11\.[2-4]/11\.1/' <<< "$CUDA_VER_MAJOR.$CUDA_VER_MINOR")"
                ;;
            esac
            ldconfig -p | grep libcudnn
            ldconfig -p | grep libnvinfer
            ldconfig -p | grep libnccl
        ) && break
        echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
    done

    # ============================================================
    # TensorRT (Hack deprecated)
    #     TODO: Detect newest version outside of CodingCafe.
    # ============================================================
    if false; then
    (
        set -e

        TRT_REPO_URL='https://developer.nvidia.com/compute/machine-learning/tensorrt/7.0/7.0.0.11/local_repos'
        TRT_FILENAME="nv-tensorrt-repo-rhel$DISTRO_VERSION_ID-cuda$CUDA_VER_MAJOR.$CUDA_VER_MINOR-trt7.0.0.11-ga-20191216-1-1.x86_64.rpm"

        if [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ]; then
            TRT_REPO_URL_CODINGCAFE='https://repo.codingcafe.org/nvidia/tensorrt'
            TRT_FILENAME_CODINGCAFE="$(                     \
                curl -sSL "$TRT_REPO_URL_CODINGCAFE"        \
                | sed -n 's/^.*href="\([^"]*\)".*$/\1/p'    \
                | grep "rhel$DISTRO_VERSION_ID"             \
                | grep 'repo'                               \
                | grep '\.rpm$'                             \
                | sort -V                                   \
                | tail -n1)"
            if [ "$TRT_FILENAME_CODINGCAFE" ]; then
                TRT_REPO_URL="$TRT_REPO_URL_CODINGCAFE"
                TRT_FILENAME="$TRT_FILENAME_CODINGCAFE"
            else
                echo "[Warning] TensorRT image not found in CodingCafe repo."
            fi
        elif [ "_$GIT_MIRROR" = "_$GIT_MIRROR_GITHUB" ]; then
            TRT_REPO_URL='https://github.com/xkszltl/Roaster/releases/download/trt'
        fi

        TRT_URL="$TRT_REPO_URL/$TRT_FILENAME"

        sudo dnf remove -y --setopt=strict=0 'nv-tensorrt-repo-*' || true
        $RPM_INSTALL "$TRT_URL"
        $RPM_INSTALL --disableplugin=axelget "tensorrt" || $RPM_UPDATE --disableplugin=axelget "tensorrt" || $RPM_REINSTALL --disableplugin=axelget "tensorrt"
        $IS_CONTAINER && sudo dnf remove -y --setopt=strict=0 'nv-tensorrt-repo-*' || true
    )
    fi

    # ============================================================
    # CUDA Samples
    # ============================================================
    (
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        cd /usr/local/cuda/samples
        export MPI_HOME=/usr/local/openmpi
        sudo make -j clean

        # CUDA 10.2 does not build due to missing nvscibuf.
        # See discussion in https://devtalk.nvidia.com/default/topic/1067000/where-is-quot-nvscibuf-h-quot-/?offset=13
        VERBOSE=1 time sudo make -j$(nproc) -k || true

        for cuda_util in deviceQuery{,Drv} topologyQuery {bandwidth,p2pBandwidthLatency}Test; do
            "bin/$(uname -p)/linux/release/$cuda_util" || true
        done
    )
)
sudo rm -vf $STAGE/cuda
sync || true
