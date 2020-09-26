# ================================================================
# Install Packages
# ================================================================

for subset in pkg-{stable,skip,all}; do
    [ -e $STAGE/$subset ] && ( set -xe
        for skip in true false; do
        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            $RPM_UPDATE && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done
        done

        # ------------------------------------------------------------
        # Pin to CUDA 11.0 for now.
        # Known issues for CUDA 11.1:
        #   - LLVM openmp failed to build during cmake config.
        #   - Missing matching cuDNN/TensorRT.
        # TODO: Remove "11-0"
        # ------------------------------------------------------------
        CUDA_PKGS='cuda'
        if $IS_CONTAINER; then
            CUDA_PKGS=''
            for i in 'compat' 'toolkit'; do
                CUDA_PKGS="$CUDA_PKGS $(                        \
                    dnf list -q "cuda-$i-11-0[0-9\-]*"          \
                    | sed -n "s/^\(cuda-$i-[0-9\-]*\).*/\1/p"   \
                    | sort -Vu                                  \
                    | tail -n1                                  \
                )"
            done
        fi

        # ------------------------------------------------------------
        # Annotation:
        # [!] Stable.
        #     These are low-level or very important packages.
        #     Their changes usually happens with distro-wide updates and worth a rebuild.
        # ------------------------------------------------------------
        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            echo "
                [!] devtoolset-{7,8,9}{,-*}
                [!] llvm-toolset-7{,-*}

                qpid-cpp-client{,-*}
                [!] gcc{,-*}
                {distcc,ccache}{,-*}
                {openmpi,mpich-3.{0,2}}{,-devel,-doc,-debuginfo}
                java-11-openjdk{,-*}
                rh-dotnet{21,22,31}{,-lttng-ust,-userspace-rcu}{,-devel,-debuginfo}
                octave{,-*}
                [!] {gdb,{l,s}trace}{,-*}
                [!] {pax-utils,prelink}{,-*}
                {gperf,gperftools,valgrind,perf}{,-*}
                {make,ninja-build,cmake{,3},autoconf,libtool}{,-*}
                {ant,maven}{,-*}
                {git,rh-git218,subversion,mercurial}{,-*}
                doxygen{,-*}
                pandoc{,-*}
                swig{,-*}
                sphinx{,-*}

                [!] vim{,-*}
                dos2unix{,-*}

                [!] bash{,-*}
                {fish,zsh,mosh,tmux}{,-*}
                [!] {bc,gawk,man,pv,sed,time,which}{,-*}
                [!] parallel{,-*}
                jq{,-*}
                [!] {tree,whereami,mlocate,lsof}{,-*}
                [!] {ftp{,lib},telnet,tftp,rsh}{,-debuginfo}
                {h,if,io,latency,power,tip}top{,-*}
                iproute{,-*}
                {ibutils,infiniband-diags}{,-*}
                lshw{,-*}
                procps-ng{,-*}
                [!] {axel,curl,net-tools,wget}{,-*}
                {f,tc,dhc,libo,io}ping{,-*}
                hping3{,-*}
                [!] {traceroute,mtr,rsync,tcpdump,whois,net-snmp}{,-*}
                torsocks{,-*}
                [!] {core,diff,elf,find,ib,ip,pci,usb,yum-}utils{,-*}
                nextgen-yum4{,-*}
                dnf-plugins-core{,-*}
                {bridge,crypto}-utils{,-*}
                [!] util-linux{,-*}
                [!] moreutils{,-debuginfo}
                [!] papi{,-*}
                rpmdevtools
                rpm-build
                cyrus-imapd{,-*}
                GeoIP{,-*}
                [!] {device-mapper,lvm2}{,-*}
                {d,sys}stat{,-*}
                [!]kernel-tools{,-*}
                {lm_sensors,hddtemp,smartmontools,lsscsi,bmon}{,-*}
                [!]tuned{,-*}
                [!] {{e2fs,btrfs-,xfs,ntfs}progs,xfsdump,nfs-utils}{,-*}
                [!] fuse{,-devel,-libs}
                dd{,_}rescue{,-*}
                [!] {docker-{ce,compose},container-selinux}{,-*}
                createrepo{,_c}{,-*}
                environment-modules{,-*}
                munge{,-*}

                [!] scl-utils{,-*}

                ncurses{,-*}
                [!] hwloc{,-*}
                [!] numa{ctl,d}{,-*}
                icu{,-*}
                [!] {glibc{,-devel},libgcc}
                [!] {gmp,mpfr,libmpc}{,-*}
                [!] lib{asan,lsan,tsan,ubsan}{,-debuginfo}
                lib{exif,jpeg-turbo,tiff,png,gomp,gphoto2}{,-*}
                giflib{,-*}
                OpenEXR{,-*}
                {libv4l,v4l-utils}{,-*}
                libunicap{,gtk}{,-*}
                [!] libglvnd{,-*}
                lib{dc,raw}1394{,-*}
                cairo{,-*}
                gnuplot{,-debuginfo,-doc}
                {freetype,harfbuzz,pango}{,-*}
                {zlib,libzip,{,lib}zstd,lz4,{,p}{bzip2,xz},pigz,cpio,tar,snappy,unrar}{,-*}
                [!] libaio{,-*}
                lib{telnet,ssh{,2},curl,ffi,edit,icu,xslt}{,-*}
                httpd24-libcurl{,-*}
                [!] boost{,-*}
                {flex,cups,bison,antlr}{,-*}
                [!] openssl{,-*}
                open{blas,cv,ldap,ni,ssh}{,-*}
                {atlas,eigen3}{,-*}
                lapack{,64}{,-*}
                {libsodium,mbedtls}{,-*}
                libev{,-devel,-source,-debuginfo}
                libevent{,-*}
                utf8proc{,-*}
                {asciidoc,gettext,xmlto,c-ares,pcre{,2}}{,-*}
                librados2{,-*}
                pugixml{,-*}
                libyaml{,-*}
                {gflags,glog,gmock,gtest,protobuf}{,-*}
                {jsoncpp,rapidjson}{,-*}
                {redis,hiredis}{,-*}
                zeromq{,-*}
                ImageMagick{,-*}
                qt5-*
                yasm{,-*}
                docbook{,5,2X}{,-*}
                txt2man
                nagios{,-selinux,-devel,-debuginfo,-plugins-all}
                {nrpe,nsca}
                {collectd,rrdtool,pnp4nagios}{,-*}
                [!] $CUDA_PKGS
                [!] lib{cudnn8{,-devel},nccl{,-devel,-static},nv{infer{,-plugin},{,onnx}parsers}-devel}
                [!] nvidia-container-runtime

                hdf5{,-*}
                {leveldb,lmdb}{,-*}
                mariadb{,-*}
                rh-postgresql10{,-postgresql{,-*}}

                {fio,{file,sys}bench}{,-*}

                [!] {,pam_}krb5{,-*}
                [!] {sudo,nss,sssd,authconfig}{,-*}
                gnome-keyring{,-*}

                gitlab-runner

                youtube-dl

                privoxy{,-*}

                XXXXXXXX_wine

                [!] libselinux{,-*}
                [!] se{troubleshoot,tools}{,-*}
                [!] {selinux-policy,policycoreutils}{,-*}

                mod_authnz_*

                cabextract{,-*}

                anaconda{,-*}
                libreoffice{,-*}
                perl{,-*}
                python{,36}{,-devel,-debug{,info}}
                {python27,rh-python38}{,-python-{devel,debug{,info}}}
                {python{2,36},{python27,rh-python36}-python}-pip
                {ruby,rh-ruby26}{,-*}
                lua{,-*}
            " \
            | sed 's/^[[:space:]]*//'                                                                       \
            | sed "$([ "_$subset" != '_pkg-stable' ] && echo 's/^\[!\].*//p' || echo 's/^//')"              \
            | sed -n "$([ "_$subset" = '_pkg-stable' ] && echo 's/^\[!\][[:space:]]*//p' || echo '/./p')"   \
            | xargs -n10 echo "$RPM_INSTALL $([ "_$subset" != '_pkg-all' ] && echo --setopt=strict=0)"      \
            | sed 's/^/set -xe; /'                                                                          \
            | bash                                                                                          \
            && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done

        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            $RPM_UPDATE && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done

        $IS_CONTAINER || sudo package-cleanup --oldkernels --count=3
        sudo dnf autoremove -y

        # ------------------------------------------------------------
        # Cite parallel.
        # ------------------------------------------------------------

        which parallel 2>/dev/null && sudo parallel --will-cite < /dev/null

        # ------------------------------------------------------------
        # Manually symlink latest CUDA in docker.
        # ------------------------------------------------------------

        $IS_CONTAINER && ls -d /usr/local/cuda-*/ | sort -V | tail -n1 | sudo xargs -I{} ln -sf {} /usr/local/cuda

        # ------------------------------------------------------------
        # Remove suspicious python modules that can cause pip>=10 to crash.
        # ------------------------------------------------------------

        find /usr/lib{,64}/python*/site-packages -name '*.dist-info' -type f -print0 | xargs -0r rpm -qf | grep -v ' ' | tr '\n' '\0' | xargs -0r dnf remove -y

        # ------------------------------------------------------------
        # Install python utilities.
        # ------------------------------------------------------------

        if [ "_$subset" = '_pkg-skip' ] || [ "_$subset" = '_pkg-all' ]; then
            "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" giampaolo/psutil,release- nicolargo/glances,v
        fi
    )
    sudo rm -vf $STAGE/$subset
    sync || true
done
