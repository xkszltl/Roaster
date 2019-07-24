# ================================================================
# Install Packages
# ================================================================

for i in pkg-{stable,skip,all}; do
    [ -e $STAGE/$i ] && ( set -xe
        for skip in true false; do
        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            $RPM_UPDATE $($skip && echo --skip-broken) && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
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
                [!] devtoolset-{6,7,8}{,-*}
                [!] llvm-toolset-7{,-*}

                qpid-cpp-client{,-*}
                [!] gcc{,-*}
                {distcc,ccache}{,-*}
                {openmpi,mpich-3.{0,2}}{,-devel,-doc,-debuginfo}
                java-11-openjdk{,-*}
                rh-dotnet2{1,2}{,-lttng-ust,-userspace-rcu}{,-devel,-debuginfo}
                octave{,-*}
                [!] {gdb,{l,s}trace}{,-*}
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
                [!] {bc,sed,man,pv,time,which}{,-*}
                [!] parallel{,-*}
                jq{,-*}
                [!] {tree,whereami,mlocate,lsof}{,-*}
                [!] {ftp{,lib},telnet,tftp,rsh}{,-debuginfo}
                {h,if,io,latency,power,tip}top{,-*}
                procps-ng{,-*}
                [!] {axel,curl,net-tools,wget}{,-*}
                {f,tc,dhc,libo,io}ping{,-*}
                hping3{,-*}
                [!] {traceroute,mtr,rsync,tcpdump,whois,net-snmp}{,-*}
                torsocks{,-*}
                [!] {core,elf,find,ib,ip,pci,usb,yum-}utils{,-*}
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
                {lm_sensors,hddtemp,smartmontools,lsscsi}{,-*}
                [!]tuned{,-*}
                [!] {{e2fs,btrfs-,xfs,ntfs}progs,xfsdump,nfs-utils}{,-*}
                [!] fuse{,-devel,-libs}
                dd{,_}rescue{,-*}
                [!] {docker-ce,container-selinux}{,-*}
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
                [!] lib{asan{,3},lsan,tsan,ubsan}{,-debuginfo}
                lib{exif,jpeg-turbo,tiff,png,gomp,gphoto2}{,-*}
                OpenEXR{,-*}
                {libv4l,v4l-utils}{,-*}
                libunicap{,gtk}{,-*}
                [!] libglvnd{,-*}
                lib{dc,raw}1394{,-*}
                freetype{,-*}
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
                {asciidoc,gettext,xmlto,c-ares,pcre{,2}}{,-*}
                librados2{,-*}
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
                [!] cuda
                [!] https://developer.download.nvidia.com/compute/machine-learning/repos/rhel7/x86_64/lib{cudnn7{,-devel}-7.6.1.34-1.,nccl{,-devel,-static}-2.4.7-1+,nvinfer{5,-devel}-5.1.5-1.}cuda10.1.x86_64.rpm
                [!] libcudnn7{,-devel} libnccl{,-devel,-static} libnvinfer{5,-devel,-samples}
                [!] nvidia-docker2

                hdf5{,-*}
                {leveldb,lmdb}{,-*}
                mariadb{,-*}
                rh-postgresql10{,-postgresql{,-*}}

                {fio,{file,sys}bench}{,-*}

                [!] {,pam_}krb5{,-*}
                [!] {sudo,nss,sssd,authconfig}{,-*}

                gitlab-runner

                youtube-dl

                privoxy{,-*}

                wine

                [!] libselinux{,-*}
                [!] policycoreutils{,-*}
                [!] se{troubleshoot,tools}{,-*}
                [!] selinux-policy{,-*}

                mod_authnz_*

                cabextract{,-*}

                anaconda{,-*}
                libreoffice{,-*}
                perl{,-*}
                python{,36}{,-devel,-debug{,info}}
                {python27,rh-python36}{,-python-{devel,debug{,info}}}
                {python{2,36},{python27,rh-python36}-python}-pip
                {ruby,rh-ruby25}{,-*}
                lua{,-*}
            " \
            | sed 's/^[[:space:]]*//' \
            | sed "$([ "_$i" != '_pkg-stable' ] && echo 's/^\[!\].*//p' || echo 's/^//')" \
            | sed -n "$([ "_$i" = '_pkg-stable' ] && echo 's/^\[!\][[:space:]]*//p' || echo '/./p')" \
            | xargs -n10 echo "$RPM_INSTALL $([ "_$i" = '_pkg-skip' ] && echo --skip-broken)" \
            | sed 's/^/set -xe; /' \
            | bash \
            && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done

        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            $RPM_UPDATE --skip-broken && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done

        $IS_CONTAINER || sudo package-cleanup --oldkernels --count=3
        sudo yum autoremove -y

        # ------------------------------------------------------------
        # Cite parallel
        # ------------------------------------------------------------

        which parallel 2>/dev/null && sudo parallel --will-cite < /dev/null

        # ------------------------------------------------------------
        # Remove suspicious python modules that can cause pip>=10 to crash.
        # ------------------------------------------------------------

        find /usr/lib{,64}/python*/site-packages -name '*.dist-info' -type f -print0 | xargs -0r rpm -qf | grep -v ' ' | tr '\n' '\0' | xargs -0r yum remove -y

        # ------------------------------------------------------------
        # Install python utilities.
        # ------------------------------------------------------------

        if [ "_$i" = '_pkg-skip' ] || [ "_$i" = '_pkg-all' ]; then
            "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" giampaolo/psutil,release- nicolargo/glances,v
        fi
    )
    sudo rm -vf $STAGE/$i
    sync || true
done
