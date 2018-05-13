# ================================================================
# Install Packages
# ================================================================

for i in pkg-{skip,all}; do
    [ -e $STAGE/$i ] && ( set -xe
        for skip in true false; do
        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            $RPM_UPDATE $($skip && echo --skip-broken) && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done
        done

        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            echo "
                devtoolset-{4,6,7}{,-*}
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
                valgrind{,-*}
                doxygen{,-*}
                swig{,-*}
                sphinx{,-*}

                vim{,-*}
                dos2unix{,-*}

                {bash,fish,zsh,mosh,tmux}{,-*}
                {bc,sed,man,pv,time,which}{,-*}
                {parallel,jq}{,-*}
                {tree,whereami,mlocate,lsof}{,-*}
                {ftp{,lib},telnet,tftp,rsh}{,-debuginfo}
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
                rpmdevtools
                rpm-build
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
                munge{,-*}

                scl-utils{,-*}

                ncurses{,-*}
                hwloc{,-*}
                icu{,-*}
                {glibc{,-devel},libgcc}
                {gmp,mpfr,libmpc}{,-*}
                gperftools{,-*}
                lib{asan{,3},tsan,ubsan}{,-*}
                lib{exif,jpeg-turbo,tiff,png,gomp,gphoto2}{,-*}
                OpenEXR{,-*}
                {libv4l,v4l-utils}{,-*}
                libunicap{,gtk}{,-*}
                libglvnd{,-*}
                lib{dc,raw}1394{,-*}
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
                zeromq{,-*}
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

                gitlab-runner

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

                *-fonts{,-*}
            " | xargs -n5 echo "$RPM_INSTALL $([ $i = pkg-skip ] && echo --skip-broken)" | bash && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done

        which parallel 2>/dev/null && sudo parallel --will-cite < /dev/null

        # ------------------------------------------------------------

        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            $RPM_UPDATE --skip-broken && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done

        $IS_CONTAINER || sudo package-cleanup --oldkernels --count=3
        sudo yum autoremove -y

        # ------------------------------------------------------------
        # Ruby gem Packages
        # ------------------------------------------------------------

        sudo gem install fpm

        # ------------------------------------------------------------
        # Python pip Packages
        # ------------------------------------------------------------

        sudo pip install -U docker-squash

        # TODO: Remove downgrade once the compatibility issue between docker 3.0.1 and docker-squash is solved.
        sudo pip install 'docker<3'

        # ------------------------------------------------------------

        sudo updatedb
    )
    sudo rm -vf $STAGE/$i
    sync || true
done
