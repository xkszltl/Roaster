# ================================================================
# Install Extra CUDA Packages
# ================================================================

[ -e $STAGE/cuda ] && ( set -xe
    cd $SCRATCH

    [ -x '/usr/local/cuda/bin/nvcc' ]
    export CUDA_VER="$(/usr/local/cuda/bin/nvcc --version | sed -n 's/.*[[:space:]]V\([0-9\.]*\).*/\1/p')"
    export CUDA_VER_MAJOR="$(cut -d'.' -f1 <<< "$CUDA_VER")"
    export CUDA_VER_MINOR="$(cut -d'.' -f2 <<< "$CUDA_VER")"
    export CUDA_VER_BUILD="$(cut -d'.' -f3 <<< "$CUDA_VER")"

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

        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-7
            set -xe
            export CC="gcc" CXX="g++"
            ;;
        'ubuntu')
            export CC="gcc-7" CXX="g++-7"
            ;;
        esac

        cd /usr/local/cuda/samples
        export MPI_HOME=/usr/local/openmpi
        sudo make -j clean

        # CUDA 10.2 does not build due to missing nvscibuf.
        # See discussion in https://devtalk.nvidia.com/default/topic/1067000/where-is-quot-nvscibuf-h-quot-/?offset=13
        VERBOSE=1 time sudo make -j$(nproc) -k || true
    )
)
sudo rm -vf $STAGE/cuda
sync || true
