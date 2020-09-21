# ================================================================
# Install Intel Libraries
# ================================================================

[ -e $STAGE/intel ] && ( set -xe
    cd $SCRATCH
    mkdir -p intel
    cd $_

    export INTEL_REPO="https://repo.codingcafe.org/intel"
    export INTEL_SITE="http://registrationcenter-download.intel.com/akdlm/irc_nas/tec"

    parallel -j0 --line-buffer --bar 'bash -c '"'"'
        set -xe
        if [ "{}" = "_" ]; then
            if [ -d '/opt/intel' ] && rpm -qf '/opt/intel'; then
                sudo dnf remove -y $(rpm -qf '/opt/intel' | sed -n '/^intel-/p')
            fi
            sudo rm -rf '/opt/intel'
        else
            mkdir -p "{}"
            pushd $_
            if [ '"_$GIT_MIRROR"' = '"_$GIT_MIRROR_CODINGCAFE"' ]; then
                URL="'"$INTEL_REPO"'/$(curl -sSL '"$INTEL_REPO"'/ | sed -n "s/.*href=\"\([^\"]*l_{}[^\"]*\)\".*/\1/p" | sort -V | tail -n1)"
            else
                URL="'"$INTEL_SITE"'/$(sed -n "s/.*[[:space:]]\([0-9]*\/l_{}_[^[:space:]]*\).*/\1/p" "'"$ROOT_DIR/repo-cache.sh"'")"
            fi
            curl -sSL "$URL" | tar --strip-components=1 -zxv
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
        sudo $i/install.sh --silent $i/silent_install.cfg
    done

    sudo ldconfig

    cd
    rm -rf $SCRATCH/intel
)
sudo rm -vf $STAGE/intel
sync || true
