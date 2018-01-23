# ================================================================
# OpenMPI
# ================================================================

[ -e $STAGE/opmi ] && ( set -e
    cd $SCRATCH

    git clone $GIT_MIRROR/open-mpi/ompi.git
    cd ompi
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    . scl_source enable devtoolset-6

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

    cd
    rm -rf $SCRATCH/opmi
)
rm -rvf $STAGE/opmi
sync || true
