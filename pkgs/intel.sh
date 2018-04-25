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
        if [ "{}" = "_" ]; then
            sudo yum remove -y intel-*
        else
            mkdir -p "{}"
            pushd $_
            curl -sSL '"$INTEL_REPO"'/$(curl -sSL '"$INTEL_REPO"'/ | sed -n "s/.*href=\"\([^\"]*l_{}[^\"]*\)\".*/\1/p" | sort -V | tail -n1) | tar --strip-components=1 -zxv
            cat silent.cfg                                  \
            | sed "s/^\([^#]*ACCEPT_EULA=\).*/\1accept/"    \
            | sed "s/^\([^#]*PSET_MODE=\).*/\1install/"     \
            > silent_install.cfg
            cat silent.cfg                                  \
            | sed "s/^\([^#]*ACCEPT_EULA=\).*/\1accept/"    \
            | sed "s/^\([^#]*COMPONENTS=\).*/\1ALL/"        \
            | sed "s/^\([^#]*PSET_MODE=\).*/\1uninstall/"   \
            > silent_uninstall.cfg
        fi
    '"'" ::: daal ipp mkl mpi tbb _

    for i in $(ls -d */ | sed 's/\///'); do
        echo "Installing Intel $(tr [a-z] [A-Z] <<< $i)..."
        # sudo $i/install.sh --silent $i/silent_uninstall.cfg || true
        sudo $i/install.sh --silent $i/silent_install.cfg
    done
    
    sudo ldconfig

    cd
    rm -rf $SCRATCH/intel
)
sudo rm -vf $STAGE/intel
sync || true
