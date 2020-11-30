# ================================================================
# OpenMPI
# ================================================================

[ -e $STAGE/ompi ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" open-mpi/ompi,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd ompi

    # ------------------------------------------------------------

    "$ROOT_DIR/geo/maven-mirror.sh"
    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-9 || exit 1
            set -xe
            export CC="gcc" CXX="g++"
            ;;
        'ubuntu')
            export CC="gcc-8" CXX="g++-8"
            ;;
        esac

        cuda_nvcc="$(which nvcc || echo /usr/local/cuda/bin/nvcc)"
        cuda_root="$("$cuda_nvcc" --version > /dev/null && readlink -e "$(dirname "$cuda_nvcc")/..")"

        ./autogen.pl
        ./configure                             \
            --enable-mpi-cxx                    \
            --enable-mpi-ext                    \
            "$(javac -version > /dev/null && echo '--enable-mpi-java')" \
            --enable-mpirun-prefix-by-default   \
            --enable-sparse-groups              \
            --enable-static                     \
            --prefix="$INSTALL_ABS/openmpi"     \
            "$(sed 's/\(..*\)/--with-cuda=\1/' <<< "$cuda_root")"   \
            --with-sge                          \
            --with-slurm                        \
            --with-ucx=/usr/local

        make -j$(nproc)
        make -j install

        find "$INSTALL_ABS" -name '*.la' | xargs -r sed -i "s/$(sed 's/\([\\\/\-\.]\)/\\\1/g' <<< "$INSTALL_ROOT")//g"
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/ompi
)
sudo rm -vf $STAGE/ompi
sync || true
