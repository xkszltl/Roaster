# ================================================================
# Install Intel Libraries
# ================================================================

[ -e $STAGE/intel ] && ( set -xe
    case "$DISTRO_ID" in
    'debian')
        sudo apt-get update -y
        # Keep them separated to allow easy cherry-picking.
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y intel-oneapi-{ccl,dal,dnnl,ipp{,cp},mkl,mpi,tbb}{,-devel}
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y intel-oneapi-{advisor,inspector,vtune}
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y intel-oneapi-{compiler-{dpcpp-cpp{,-and-cpp-classic},fortran},dpcpp-{ct,debugger},libdpstd-devel}
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y intel-oneapi-dev-utilities intel-oneapi-diagnostics-utility
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y intel-basekit
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y intel-hpckit
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y intel-iotkit
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y intel-dlfdkit
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y intel-aikit
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y intel-renderkit
        ;;
    *)
        cd $SCRATCH
        mkdir -p intel
        cd $_

        export INTEL_REPO="https://repo.codingcafe.org/intel"
        export INTEL_SITE="http://registrationcenter-download.intel.com/akdlm/irc_nas/tec"

        parallel -j0 --line-buffer --bar 'bash -c '"'"'
            set -xe
            if [ "{}" = "_" ]; then
                if [ -d "/opt/intel" ] && rpm -qf "/opt/intel"; then
                    sudo dnf remove -y $(rpm -qf "/opt/intel" | sed -n "/^intel-/p")
                fi
                sudo rm -rf "/opt/intel"
            else
                if [ '"_$GIT_MIRROR"' = '"_$GIT_MIRROR_CODINGCAFE"' ]; then
                    URL="'"$INTEL_REPO"'/$(curl -sSL '"$INTEL_REPO"'/ | sed -n "s/.*href=\"\([^\"]*l_{}[^\"]*\)\".*/\1/p" | sort -V | tail -n1)"
                else
                    URL="'"$INTEL_SITE"'/$(sed -n "s/.*[[:space:]]\([0-9]*\/l_{}_[^[:space:]]*\).*/\1/p" "'"$ROOT_DIR/repo-cache.sh"'")"
                fi
                for retry in $(seq 10 -1 0); do
                    rm -rf "{}"{,.downloading}
                    mkdir -p "{}.downloading"
                    curl -sSL "$URL" | tar --strip-components=1 -C "{}.downloading" -zxv || continue
                    mv -f "{}"{.downloading,}
                    break
                done
                [ -d "{}" ]
                cat "{}/silent.cfg"                             \
                | sed "s/^\([^#]*ACCEPT_EULA=\).*/\1accept/"    \
                | sed "s/^\([^#]*PSET_MODE=\).*/\1install/"     \
                > "{}/silent_install.cfg"
                cat "{}/silent.cfg"                             \
                | sed "s/^\([^#]*ACCEPT_EULA=\).*/\1accept/"    \
                | sed "s/^\([^#]*COMPONENTS=\).*/\1ALL/"        \
                | sed "s/^\([^#]*PSET_MODE=\).*/\1uninstall/"   \
                > "{}/silent_uninstall.cfg"
            fi
        '"'" ::: daal ipp mkl mpi tbb _

        for i in $(ls -d */ | sed 's/\///'); do
            echo "Installing Intel $(tr [a-z] [A-Z] <<< $i)..."
            sudo $i/install.sh --silent $i/silent_install.cfg
        done

        sudo ldconfig

        cd
        rm -rf $SCRATCH/intel
        ;;
    esac
)
sudo rm -vf $STAGE/intel
sync || true
