# ================================================================
# Install Packages
# ================================================================

for subset in pkg-{stable,skip,all}; do
    [ -e $STAGE/$subset ] && ( set -xe
        for skip in true false; do
        for attempt in $(seq "$RPM_MAX_ATTEMPT" -1 0); do
            [ "$attempt" -gt 0 ] || exit 1
            $RPM_UPDATE && break
            echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
        done
        done

        # ------------------------------------------------------------
        # Annotation:
        # [!] Stable.
        #     These are low-level or very important packages.
        #     Their changes usually happens with distro-wide updates and worth a rebuild.
        # ------------------------------------------------------------
        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            echo "
                [!] devtoolset-{8,9}{,-*}
                [!] llvm-toolset-7{,-*}

                qpid-cpp-client{,-*}
                [!] gcc{,-*}
                {distcc,ccache}{,-*}
                openmpi{,-{devel,debuginfo}}
                mpich-3.{0,2}{,-{devel,doc}}
                java-11-openjdk{,-*}
                rh-dotnet{21,22,31}{,-{lttng-ust,userspace-rcu}{,-{devel,debuginfo}}}
                octave{,-{control,devel,doc,GeographicLib,general,image,io,signal,statistics}}
                [!] {gdb,{l,s}trace}{,-*}
                [!] {pax-utils,prelink}{,-*}
                {gperf,gperftools,valgrind,perf}{,-*}
                [!] autoconf{,-archive}
                [!] libtool{,-ltdl{,-devel}}
                [!] make
                ninja-build
                cmake{{,-{fedora,gui}},3{,-{data,doc,gui}}}
                {ant,maven}{,-*}
                {git,rh-git218,subversion,mercurial}{,-*}
                doxygen{,-*}
                pandoc{,-*}
                swig{,-*}

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
                rdma-core{,-*}
                librdmacm{,-utils}
                lshw{,-*}
                procps-ng{,-*}
                [!] {axel,curl,net-tools,wget}{,-*}
                {f,tc,dhc,htt,libo,io}ping{,-*}
                hping3{,-*}
                [!] {traceroute,mtr,rsync,tcpdump,whois,net-snmp}{,-*}
                [!] {apcupsd,nut}{,-*}
                torsocks{,-*}
                [!] {core,diff,elf,find,ib,ip,pci,sysfs,usb,yum-}utils{,-*}
                [!] socat
                nextgen-yum4{,-*}
                dnf-plugins-core
                yum-plugin-versionlock{,-*}
                {bridge,crypto}-utils{,-*}
                [!] man-pages
                [!] util-linux{,-*}
                [!] expect{,-devel,-debuginfo}
                [!] moreutils{,-debuginfo}
                [!] papi{,-*}
                [!] rng-tools{,-debuginfo}
                rpmdevtools
                rpm-build
                cyrus-imapd{,-*}
                GeoIP{,-*}
                [!] {device-mapper,lvm2}{,-*}
                {d,if,sys}stat{,-*}
                [!]kernel-tools{,-*}
                {lm_sensors,hddtemp,smartmontools,lsscsi,bmon}{,-*}
                [!]tuned{,-*}
                [!] {{e2fs,btrfs-,xfs,ntfs}progs,xfsdump,nfs-utils}{,-*}
                [!] fuse{,-devel,-libs}
                dd{,_}rescue{,-*}
                [!] {docker-{ce,compose},container-selinux}{,-*}
                createrepo{,_c}{,-*}
                environment-modules{,-*}
                slurm{,-*}
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
                lcov{,-*}
                giflib{,-*}
                OpenEXR{,-*}
                {libv4l,v4l-utils}{,-*}
                libunicap{,gtk}{,-*}
                [!] libglvnd{,-*}
                lib{dc,raw}1394{,-*}
                cairo{,-*}
                gnuplot{,-debuginfo,-doc}
                {freetype,harfbuzz,pango}{,-*}
                {zlib,libzip,{,lib}zstd,lz4,{,p}{bzip2,xz},pigz,cpio,tar,snappy}{,-*}
                [!] libaio{,-*}
                lib{telnet,ssh{,2},curl,ffi,edit,icu,xslt}{,-*}
                httpd24-libcurl{,-*}
                [!] boost{,-*}
                {flex,cups,bison,antlr}{,-*}
                [!] openssl{,-*}
                open{blas,cv,ldap,ni,ssh}{,-*}
                {atlas,eigen3}{,-*}
                lapack{,64}{,-*}
                {libsodium,mbedtls,udns}{,-*}
                libev{,-devel,-source,-debuginfo}
                libevent{,-*}
                utf8proc{,-*}
                {asciidoc,gettext,xmlto,c-ares,pcre{,2}}{,-*}
                librados2{,-*}
                pugixml{,-*}
                libyaml{,-*}
                byacc{,j}{,-*}
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
                python{,3}{,-{devel,debug{,info}}} python36
                {python27,rh-python38}{,-python-{devel,debug{,info}}}
                {python{2,36},{python27,rh-python36}-python}-pip
                {ruby,rh-ruby26}{,-*}
                lua{,-*}
            " \
            | sed 's/^[[:space:]]*//'                                                                       \
            | sed "$([ "_$subset" != '_pkg-stable' ] && echo 's/^\[!\].*//p' || echo 's/^//')"              \
            | sed -n "$([ "_$subset" = '_pkg-stable' ] && echo 's/^\[!\][[:space:]]*//p' || echo '/./p')"   \
            | xargs -n50 echo "$RPM_INSTALL $([ "_$subset" != '_pkg-all' ] && echo --setopt=strict=0)"      \
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
        # Remove suspicious python modules that can cause pip>=10 to crash.
        # ------------------------------------------------------------

        find /usr/lib{,64}/python*/site-packages -name '*.dist-info' -type f -print0 | xargs -0r rpm -qf | grep -v ' ' | tr '\n' '\0' | xargs -0r dnf remove -y

        # ------------------------------------------------------------
        # Install python utilities.
        # ------------------------------------------------------------

        if [ "_$subset" = '_pkg-skip' ] || [ "_$subset" = '_pkg-all' ]; then
            "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" giampaolo/psutil,release- nicolargo/glances,v
        fi

        # ------------------------------------------------------------
        # Setup firewall rules.
        # ------------------------------------------------------------

        sudo firewall-cmd --permanent --add-port=3551/tcp || $IS_CONTAINER
    )
    sudo rm -vf $STAGE/$subset
    sync || true
done
