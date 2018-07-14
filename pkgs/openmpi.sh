# ================================================================
# OpenMPI
# ================================================================

[ -e $STAGE/ompi ] && ( set -xe
    cd $SCRATCH

    until git clone --depth 1 --single-branch -b "$(git ls-remote --tags "$GIT_MIRROR/open-mpi/ompi.git" | sed -n 's/.*[[:space:]]refs\/tags\/\(v[0-9\.]*\)[[:space:]]*$/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/open-mpi/ompi.git"; do echo 'Retrying'; done
    cd ompi

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        set -xe

        ./autogen.pl
        ./configure                             \
            --enable-mpi-cxx                    \
            --enable-mpi-ext                    \
            --enable-mpi-java                   \
            --enable-mpirun-prefix-by-default   \
            --enable-sparse-groups              \
            --enable-static                     \
            --prefix="$INSTALL_ABS/openmpi"     \
            --with-cuda                         \
            --with-sge                          \
            --with-slurm

        make -j$(nproc)
        make -j install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"
    
    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/ompi
)
sudo rm -vf $STAGE/ompi
sync || true
