# ================================================================
# Install Intel Libraries
# ================================================================

[ -e $STAGE/intel ] && ( set -e
    cd $SCRATCH
    mkdir -p intel
    cd $_

    export INTEL_REPO=https://repo.codingcafe.org/intel

    for i in daal ipp mkl mpi tbb; do ( set -e
        wget $INTEL_REPO/$(curl -sSL $INTEL_REPO | sed -n 's/.*href="\(.*l_'$i'.*\)".*/\1/p' | sort -V | tail -n1)
        mkdir -p $i
        tar -xvf l_$i* -C $i --strip-components=1
        rm -rf l_$i*
    ) & done
    wait

    for i in $(ls -d */ | sed 's/\///'); do
        echo "Installing Intel $(tr [a-z] [A-Z] <<< $i)..."
        $i/install.sh --silent <(sed 's/^\([^#]*ACCEPT_EULA=\).*/\1accept/' $i/silent.cfg)
    done
    
    ldconfig &

    cd
    rm -rf $SCRATCH/intel
    wait
)
rm -rvf $STAGE/intel
sync || true
