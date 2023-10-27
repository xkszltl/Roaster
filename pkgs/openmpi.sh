# ================================================================
# OpenMPI
# ================================================================

[ -e $STAGE/ompi ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" open-mpi/ompi,v4
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd ompi

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # ------------------------------------------------------------

    "$ROOT_DIR/geo/maven-mirror.sh"
    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        cuda_nvcc="$(which nvcc || echo /usr/local/cuda/bin/nvcc)"
        [ ! -x "$cuda_nvcc" ] || cuda_root="$("$cuda_nvcc" --version > /dev/null && realpath -e "$(dirname "$cuda_nvcc")/..")"

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
sync "$STAGE" || true
