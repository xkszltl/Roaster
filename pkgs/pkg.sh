# ================================================================
# Install Packages
# ================================================================

for i in pkg-{skip,all}; do
    [ -e $STAGE/$i ] && ( set -e
        yum clean all
        rm -rf /var/cache/yum

        export RPM_MAX_ATTEMPT=10

        # TODO: Fix the following issue:
        #       LLVM may select the wrong gcc toolchain without libgcc_s integrated.
        #       The correct choice is x86_64-redhat-linux instead of x86_64-linux-gnu.
        export RPM_BLACKLIST=$(echo "
            *-debuginfo
            gcc-x86_64-linux-gnu
            python-qpid-common
            python2-paramiko
        " | sed -n 's/^[[:space:]]*\([^[:space:]][^[:space:]]*\).*/--exclude \1/p' | paste -s - | xargs)

        export RPM_CACHE_ARGS=$([ -f $RPM_CACHE_REPO ] && echo "--disableplugin=axelget,fastestmirror")

        export RPM_INSTALL="yum install -y $RPM_CACHE_ARGS --nogpgcheck $RPM_BLACKLIST"
        export RPM_UPDATE="yum update -y $RPM_CACHE_ARGS --nogpgcheck $RPM_BLACKLIST"

        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            echo "
                devtoolset-{6,7}{,-*}
                llvm-toolset-7{,-*}

                qpid-cpp-client{,-*}
                {gcc,distcc,ccache}{,-*}
                {openmpi,mpich-3.{0,2}}{,-devel,-doc,-debuginfo}
                java-1.8.0-openjdk{,-*}
                octave{,-*}
                {gdb,valgrind,perf,{l,s}trace}{,-*}
                {make,ninja-build,cmake{,3},autoconf,libtool}{,-*}
                {ant,maven}{,-*}
                {git,subversion,mercurial}{,-*}
                doxygen{,-*}
                swig{,-*}

                vim{,-*}
                dos2unix{,-*}

                {bash,fish,zsh,mosh,tmux}{,-*}
                {bc,sed,man,pv,which}{,-*}
                {parallel,jq}{,-*}
                {tree,whereami,mlocate,lsof}{,-*}
                {telnet,tftp,rsh}{,-debuginfo}
                {f,h,if,io,latency,power,tip}top{,-*}
                procps-ng{,-*}
                glances{,-*}
                {wget,axel,curl,net-tools}{,-*}
                {f,tc,dhc,libo,io}ping{,-*}
                hping3{,-*}
                {traceroute,mtr,rsync,tcpdump,whois,net-snmp}{,-*}
                torsocks{,-*}
                {bridge-,core,crypto-,elf,find,ib,ip,yum-}utils{,-*}
                moreutils{,-debuginfo}
                cyrus-imapd{,-*}
                GeoIP{,-*}
                {device-mapper,lvm2}{,-*}
                {d,sys}stat{,-*}
                {lm_sensors,hddtemp}{,-*}
                {{e2fs,btrfs-,xfs,ntfs}progs,xfsdump,nfs-utils}{,-*}
                fuse{,-devel,-libs}
                dd{,_}rescue{,-*}
                {docker-ce,container-selinux}{,-*}
                createrepo{,_c}{,-*}
                environment-modules{,-*}
                fpm2{,-*}
                munge{,-*}

                scl-utils{,-*}

                ncurses{,-*}
                hwloc{,-*}
                icu{,-*}
                {glibc{,-devel},libgcc}{,.i686}
                {gmp,mpfr,libmpc}{,-*}
                gperftools{,-*}
                lib{asan{,3},tsan,ubsan}{,-*}
                lib{exif,jpeg-turbo,tiff,png,gomp,gphoto2}{,-*}
                OpenEXR{,-*}
                {libv4l,v4l-utils}{,-*}
                libunicap{,gtk}{,-*}
                libglvnd{,-*}
                tbb{,-*}
                {bzip2,zlib,libzip,{,lib}zstd,lz4,{,p}xz,snappy}{,-*}
                lib{telnet,ssh{,2},curl,aio,ffi,edit,icu,xslt}{,-*}
                boost{,-*}
                {flex,cups,bison,antlr}{,-*}
                open{blas,cv,ldap,ni,ssh,ssl}{,-*}
                {atlas,eigen3}{,-*}
                lapack{,64}{,-*}
                {libsodium,mbedtls}{,-*}
                libev{,-devel,-source,-debuginfo}
                {asciidoc,gettext,xmlto,c-ares,pcre{,2}}{,-*}
                librados2{,-*}
                {gflags,glog,gmock,gtest,protobuf}{,-*}
                {redis,hiredis}{,-*}
                ImageMagick{,-*}
                docbook{,5,2X}{,-*}
                nagios{,-selinux,-devel,-debuginfo,-plugins-all}
                {nrpe,nsca}
                {collectd,rrdtool,pnp4nagios}{,-*}
                cuda
                nvidia-docker2

                hdf5{,-*}
                {leveldb,lmdb}{,-*}
                {mariadb,postgresql}{,-*}

                {fio,{file,sys}bench}{,-*}

                {,pam_}krb5{,-*}
                {sudo,nss,sssd,authconfig}{,-*}

                gitlab-ci-multi-runner

                youtube-dl

                privoxy{,-*}

                wine

                libselinux{,-*}
                policycoreutils{,-*}
                se{troubleshoot,tools}{,-*}
                selinux-policy{,-*}

                mod_authnz_*

                cabextract{,-*}

                anaconda{,-*}
                libreoffice{,-*}
                perl{,-*}
                python{,-*}
                python3{,-*}
                python34{,-*}
                python2{,-*}
                rh-python36{,-*}
                ruby{,-*}
                lua{,-*}
                qt5{,-*}
                *-fonts{,-*}
            " | xargs -n5 echo "$RPM_INSTALL $([ $i = pkg-skip ] && echo --skip-broken)" | bash && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done

        which parallel 2>/dev/null && parallel --will-cite < /dev/null

        # ------------------------------------------------------------

        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            $RPM_INSTALL "https://downloads.sourceforge.net/project/mscorefonts2/rpms/$(
                curl -sSL https://sourceforge.net/projects/mscorefonts2/files/rpms/                                         \
                | sed -n 's/.*\(msttcore-fonts-installer-\([0-9]*\).\([0-9]*\)-\([0-9]*\).noarch.rpm\).*/\2 \3 \4 \1/p'     \
                | sort -n | tail -n1 | cut -d' ' -f4 -
            )" && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done

        fc-cache -fv

        # ------------------------------------------------------------

        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            $RPM_UPDATE --skip-broken && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done

        $IS_CONTAINER || package-cleanup --oldkernels --count=2
        yum autoremove -y
        yum clean all
        rm -rf /var/cache/yum

        updatedb
    )
    rm -rvf $STAGE/$i
    sync || true
done
