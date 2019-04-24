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
    # TensorRT
    #     TODO: Detect newest version outside of CodingCafe.
    # ============================================================
    (
        set -e

        TRT_REPO_URL='https://developer.nvidia.com/compute/machine-learning/tensorrt/5.1/rc/local_repos'
        TRT_FILENAME="nv-tensorrt-repo-rhel7-cuda$CUDA_VER_MAJOR.$CUDA_VER_MINOR-trt5.1.2.2-rc-20190227-1-1.x86_64.rpm"

        if [ "_$GIT_MIRROR" == "_$GIT_MIRROR_CODINGCAFE" ]; then
            TRT_REPO_URL_CODINGCAFE='https://repo.codingcafe.org/nvidia/tensorrt'
            TRT_FILENAME_CODINGCAFE="$(                     \
                curl -sSL "$TRT_REPO_URL_CODINGCAFE"        \
                | sed -n 's/^.*href="\([^"]*\)".*$/\1/p'    \
                | grep 'rhel7'                              \
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
        elif [ "_$GIT_MIRROR" == "_$GIT_MIRROR_GITHUB" ]; then
            TRT_REPO_URL='https://github.com/xkszltl/Roaster/releases/download/trt'
        fi

        TRT_URL="$TRT_REPO_URL/$TRT_FILENAME"

        sudo yum remove -y --skip-broken 'nv-tensorrt-repo-*' || true
        $RPM_INSTALL "$TRT_URL"
        $RPM_INSTALL --disableplugin=axelget "tensorrt" || $RPM_UPDATE --disableplugin=axelget "tensorrt" || $RPM_REINSTALL --disableplugin=axelget "tensorrt"
        $IS_CONTAINER && sudo yum remove -y --skip-broken 'nv-tensorrt-repo-*'
    )

    # ============================================================
    # CUDA Samples
    # ============================================================
    (
        set -xe

        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-6
            set -xe
            export CC="gcc" CXX="g++"
            ;;
        'ubuntu')
            export CC="gcc-6" CXX="g++-6"
            ;;
        esac

        cd /usr/local/cuda/samples
        export MPI_HOME=/usr/local/openmpi
        sudo make -j clean
        VERBOSE=1 time sudo make -j$(nproc)
    )
)
sudo rm -vf $STAGE/cuda
sync || true
