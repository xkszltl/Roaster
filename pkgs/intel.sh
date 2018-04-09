# ================================================================
# Install Intel Libraries
# ================================================================

[ -e $STAGE/intel ] && ( set -xe
    cd $SCRATCH
    mkdir -p intel
    cd $_

    export INTEL_REPO=https://repo.codingcafe.org/intel

    parallel -j0 --line-buffer --bar 'bash -c '"'"'
        set -xe
        wget -q $INTEL_REPO/$(curl -sSL $INTEL_REPO | sed -n '"'"'s/.*href="\(.*l_{}.*\)".*/\1/p'"'"' | sort -V | tail -n1)
        mkdir -p $i
        tar -xvf l_$i* -C $i --strip-components=1
        rm -rf l_$i*
    '"'" ::: daal ipp mkl mpi tbb

    for i in $(ls -d */ | sed 's/\///'); do
        echo "Installing Intel $(tr [a-z] [A-Z] <<< $i)..."
        sudo $i/install.sh --silent <(sed 's/^\([^#]*ACCEPT_EULA=\).*/\1accept/' $i/silent.cfg)
    done
    
    sudo ldconfig

    cd
    rm -rf $SCRATCH/intel
)
sudo rm -vf $STAGE/intel
sync || true
