# ================================================================
# OpenMPI
# ================================================================

[ -e $STAGE/ompi ] && ( set -xe
    cd $SCRATCH

    until git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/open-mpi/ompi.git; do echo 'Retrying'; done
    cd ompi
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    (
        . scl_source enable devtoolset-6 || true

        set -e

        ./autogen.pl
        ./configure                             \
            --enable-mpi-cxx                    \
            --enable-mpi-ext                    \
            --enable-mpi-java                   \
            --enable-mpirun-prefix-by-default   \
            --enable-sparse-groups              \
            --enable-static                     \
            --prefix=/usr/local/openmpi         \
            --with-cuda                         \
            --with-sge                          \
            --with-slurm

        make -j$(nproc)
        make -j install
    )

    cd
    rm -rf $SCRATCH/ompi
)
sudo rm -vf $STAGE/ompi
sync || true
