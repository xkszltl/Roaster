#!/bin/bash

set -e
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# ================================================================
# Environment Configuration
# ================================================================

export SCRATCH=/tmp/scratch
export STAGE=/etc/codingcafe/stage

export RPM_CACHE_REPO=/etc/yum.repos.d/cache.repo

# ----------------------------------------------------------------

export GIT_MIRROR_GITHUB=https://github.com
export GIT_MIRROR_CODINGCAFE=https://git.codingcafe.org/Mirrors

# ----------------------------------------------------------------

export IS_CONTAINER=$([ -e /proc/1/cgroup ] && [ $(sed -n 's/^[^:]*:[^:]*:\(..\)/\1/p' /proc/1/cgroup | wc -l) -gt 0 ] && echo true || echo false)

# ================================================================
# Infomation
# ================================================================

echo '================================================================'
date
echo '----------------------------------------------------------------'
echo '                  CodingCafe CentOS Deployment                  '
$IS_CONTAINER && \
echo '                       -- In Container --                       '
echo '----------------------------------------------------------------'
echo -n '| Node     | '
uname -no
echo -n '| Kernel   | '
uname -sr
echo -n '| Platform | '
uname -m
echo '----------------------------------------------------------------'
df -h --sync --output=target,fstype,size,used,avail,pcent,source | sed 's/^/| /'
echo '================================================================'
echo
echo

# ================================================================
# Configure Scratch Directory
# ================================================================

rm -rvf $SCRATCH
mkdir -p $SCRATCH
# $IS_CONTAINER || mount -t tmpfs -o size=100% tmpfs $SCRATCH
cd $SCRATCH

# ================================================================
# Initialize Setup Stage
# ================================================================

[ -d $STAGE ] && [ $# -eq 0 ] || ( set -e
    rm -rvf $STAGE
    mkdir -p $(dirname $STAGE)/.$(basename $STAGE)
    cd $_
    [ $# -gt 0 ] && touch $@ || touch repo pkg auth slurm ompi nagios ss tex cmake llvm boost jemalloc gflags glog protobuf leveldb opencv rocksdb caffe caffe2
    sync || true
    cd $SCRATCH
    mv -vf $(dirname $STAGE)/.$(basename $STAGE) $STAGE
)

# ================================================================
# YUM Configuration
# ================================================================

[ -e $STAGE/repo ] && ( set -e
    until yum install -y sed yum-utils; do echo 'Retrying'; done

    yum-config-manager --setopt=tsflags= --save

    [ -f $RPM_CACHE_REPO ] || yum-config-manager --add-repo https://repo.codingcafe.org/cache/el/7/cache.repo

    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}{{base,updates,extras,centosplus}{,-source},base-debuginfo}\; | sed 's/%/ /g' | bash

    until yum install -y yum-plugin-{priorities,fastestmirror} bc {core,find,ip}utils curl kernel-headers; do echo 'Retrying'; done

    until yum install -y epel-release; do echo 'Retrying'; done
    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}epel{,-source,-debuginfo}\; | sed 's/%/ /g' | bash

    until yum install -y yum-axelget; do echo 'Retrying'; done

    until yum install -y centos-release-scl{,-rh}; do echo 'Retrying'; done
    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}centos-sclo-{sclo,rh}{,-source,-debuginfo}\; | sed 's/%/ /g' | bash

    until yum update -y --skip-broken; do echo 'Retrying'; done
    yum update -y || true

    rpm -i $(
        curl -s https://developer.nvidia.com/cuda-downloads                     \
        | grep 'Linux/x86_64/CentOS/7/rpm (network)'                            \
        | head -n1                                                              \
        | sed "s/.*\('.*developer.download.nvidia.com\/[^\']*\.rpm'\).*/\1/"
    ) || true
    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}cuda\; | sed 's/%/ /g' | bash

    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}docker-ce-stable{,-source,-debuginfo}\; | sed 's/%/ /g' | bash

    curl -sSL https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.rpm.sh | bash
    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}runner_gitlab-ci-multi-runner{,-source}\; | sed 's/%/ /g' | bash

    rm -rvf /etc/yum.repos.d/gitlab_gitlab-ce.repo
    curl -sSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | bash
    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}gitlab_gitlab-ce{,-source}\; | sed 's/%/ /g' | bash

    until yum update -y --skip-broken; do echo 'Retrying'; done
    yum update -y || true
) && rm -rvf $STAGE/repo
sync || true

export GIT_MIRROR=$(
    for i in $(env | sed -n 's/^GIT_MIRROR_[^=]*=//p'); do :
        ping -nfc 100 $(sed 's/.*:\/\///' <<<"$i" | sed 's/\/.*//')                         \
        | sed -n '/ms$/p'                                                                   \
        | sed 's/.*[^0-9]\([0-9]*\)%.*[^0-9\.]\([0-9\.]*\).*ms/\1 \2/'                      \
        | sed 's/.*ewma.*\/\([0-9\.]*\).*/\1/'                                              \
        | xargs                                                                             \
        | sed 's/\([0-9\.][0-9\.]*\).*[[:space:]]\([0-9\.][0-9\.]*\).*/\2\*\(\1\*10+1\)/'   \
        | bc
        echo "$i"
    done | paste - - | sort -n | head -n1 | xargs -n1 | tail -n1
)

echo "GIT_MIRROR=$GIT_MIRROR"

# ================================================================
# Install Packages
# ================================================================

[ -e $STAGE/pkg ] && ( set -e
    export RPM_CACHE_ARGS=$([ -f $RPM_CACHE_REPO ] && echo "--disableplugin=axelget,fastestmirror")

    until yum install -y --nogpgcheck $RPM_CACHE_ARGS           \
                                                                \
    qpid-cpp-client{,-*}                                        \
    {gcc,distcc,ccache}{,-*}                                    \
    {openmpi,mpich-3.{0,2}}{,-devel,-doc,-debuginfo}            \
    java-1.8.0-openjdk{,-*}                                     \
    lua{,-*}                                                    \
    octave{,-*}                                                 \
    {gdb,valgrind,perf,{l,s}trace}{,-*}                         \
    {make,ninja-build,cmake{,3},autoconf,libtool}{,-*}          \
    {ant,maven}{,-*}                                            \
    {git,subversion,mercurial}{,-*}                             \
    doxygen{,-*}                                                \
    swig{,-*}                                                   \
                                                                \
    vim{,-*}                                                    \
    dos2unix{,-*}                                               \
                                                                \
    {bash,fish,zsh,mosh,tmux}{,-*}                              \
    {bc,sed,man,pv,which}{,-*}                                  \
    {parallel,jq}{,-*}                                          \
    {tree,whereami,mlocate,lsof}{,-*}                           \
    {telnet,tftp,rsh}{,-debuginfo}                              \
    {f,h,if,io,latency,power,tip}top{,-*}                       \
    procps-ng{,-*}                                              \
    glances{,-*}                                                \
    {wget,axel,curl,net-tools}{,-*}                             \
    {f,tc,dhc,libo,io}ping{,-*}                                 \
    hping3{,-*}                                                 \
    {traceroute,mtr,rsync,tcpdump,whois,net-snmp}{,-*}          \
    torsocks{,-*}                                               \
    {bridge-,core,crypto-,elf,find,ib,ip,yum-}utils{,-*}        \
    moreutils{,-debuginfo}                                      \
    cyrus-imapd{,-*}                                            \
    GeoIP{,-*}                                                  \
    {device-mapper,lvm2}{,-*}                                   \
    {d,sys}stat{,-*}                                            \
    {lm_sensors,hddtemp}{,-*}                                   \
    {{e2fs,btrfs-,xfs,ntfs}progs,xfsdump,nfs-utils}{,-*}        \
    fuse{,-devel,-libs}                                         \
    dd{,_}rescue{,-*}                                           \
    {docker-ce,container-selinux}{,-*}                          \
    createrepo{,_c}{,-*}                                        \
    environment-modules{,-*}                                    \
    fpm2{,-*}                                                   \
    munge{,-*}                                                  \
                                                                \
    scl-utils{,-*}                                              \
                                                                \
    ncurses{,-*}                                                \
    hwloc{,-*}                                                  \
    icu{,-*}                                                    \
    {glibc{,-devel},libgcc}{,.i686}                             \
    {gmp,mpfr,libmpc}{,-*}                                      \
    gperftools{,-*}                                             \
    lib{asan{,3},tsan,ubsan}{,-*}                               \
    lib{exif,jpeg-turbo,tiff,png,gomp,gphoto2}{,-*}             \
    OpenEXR{,-*}                                                \
    {libv4l,v4l-utils}{,-*}                                     \
    libunicap{,gtk}{,-*}                                        \
    libglvnd{,-*}                                               \
    tbb{,-*}                                                    \
    {bzip2,zlib,libzip,{,lib}zstd,lz4,{,p}xz,snappy}{,-*}       \
    lib{telnet,ssh{,2},curl,aio,ffi,edit,icu,xslt}{,-*}         \
    boost{,-*}                                                  \
    {flex,cups,bison,antlr}{,-*}                                \
    open{blas,cv,ldap,ni,ssh,ssl}{,-*}                          \
    {atlas,eigen3}{,-*}                                         \
    lapack{,64}{,-*}                                            \
    {libsodium,mbedtls}{,-*}                                    \
    libev{,-devel,-source,-debuginfo}                           \
    {asciidoc,gettext,xmlto,c-ares,pcre{,2}}{,-*}               \
    librados2{,-*}                                              \
    {gflags,glog,gmock,gtest,protobuf}{,-*}                     \
    {redis,hiredis}{,-*}                                        \
    ImageMagick{,-*}                                            \
    docbook{,5,2X}{,-*}                                         \
    nagios{,selinux,devel,debuginfo,-plugins-all}               \
    {nrpe,nsca}                                                 \
    {collectd,rrdtool,pnp4nagios}{,-*}                          \
    cuda                                                        \
    nvidia-docker2                                              \
                                                                \
    hdf5{,-*}                                                   \
    {leveldb,lmdb}{,-*}                                         \
    {mariadb,postgresql}{,-*}                                   \
                                                                \
    {fio,filebench}{,-*}                                        \
                                                                \
    {,pam_}krb5{,-*}                                            \
    {sudo,nss,sssd,authconfig}{,-*}                             \
                                                                \
    gitlab-ci-multi-runner                                      \
                                                                \
    youtube-dl                                                  \
                                                                \
    privoxy{,-*}                                                \
                                                                \
    wine                                                        \
                                                                \
    libselinux{,-*}                                             \
    policycoreutils{,-*}                                        \
    se{troubleshoot,tools}{,-*}                                 \
    selinux-policy{,-*}                                         \
                                                                \
    mod_authnz_*                                                \
                                                                \
    cabextract{,-*}                                             \
                                                                \
    devtoolset-{3,4,6,7}                                        \

    do echo 'Retrying'; done

    # TODO: Fix the following issue:
    #       LLVM may select the wrong gcc toolchain without libgcc_s integrated.
    #       The correct choice is x86_64-redhat-linux instead of x86_64-linux-gnu.
    yum remove -y gcc-x86_64-linux-gnu

    yum autoremove -y
    yum clean packages

    parallel --will-cite < /dev/null

    nvidia-smi

    # ------------------------------------------------------------

    for i in anaconda libreoffice perl python{,2,34} qt5 ruby *-fonts; do :
        until yum install -y --skip-broken $RPM_CACHE_ARGS $i{,-*}; do echo 'Retrying'; done
    done

    until yum install -y "https://downloads.sourceforge.net/project/mscorefonts2/rpms/$(
        curl -sSL https://sourceforge.net/projects/mscorefonts2/files/rpms/                                         \
        | sed -n 's/.*\(msttcore-fonts-installer-\([0-9]*\).\([0-9]*\)-\([0-9]*\).noarch.rpm\).*/\2 \3 \4 \1/p'     \
        | sort -n | tail -n1 | cut -d' ' -f4 -
    )"; do echo 'Retrying'; done

    fc-cache -fv

    # ------------------------------------------------------------

    ( set -e
        if [ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ]; then
            export HTTP_PROXY=proxy.codingcafe.org:8118
            [ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
            [ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
            [ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY

            curl -sSL https://repo.codingcafe.org/nvidia/cudnn/$(curl -sSL https://repo.codingcafe.org/nvidia/cudnn | sed -n 's/.*href="\(.*linux-x64.*\)".*/\1/p' | sort | tail -n1) | tar -zxvf - -C /usr/local/
        else
            curl -sSL https://developer.download.nvidia.com/compute/redist/cudnn/v7.0.3/cudnn-9.0-linux-x64-v7.tgz | tar -zxvf - -C /usr/local/
        fi
        curl -sSL https://repo.codingcafe.org/nvidia/nccl/$(curl -sSL https://repo.codingcafe.org/nvidia/nccl | sed -n 's/.*href="\(.*amd64.*\)".*/\1/p' | sort | tail -n1) | tar -Jxvf - --strip-components=1 -C /usr/local/cuda
        ldconfig

        cd $(dirname $(which nvcc))/../samples
        . scl_source enable devtoolset-6
        VERBOSE=1 time make -j
    )

    until yum update -y --skip-broken; do echo 'Retrying'; done
    yum update -y || true

    $IS_CONTAINER || package-cleanup --oldkernels --count=2
    yum autoremove -y
    yum clean all

    updatedb
) && rm -rvf $STAGE/pkg
sync || true

# ================================================================
# Git Configuration
# ================================================================

git config --global user.name       'Tongliang Liao'
git config --global user.email      'xkszltl@gmail.com'
git config --global push.default    'matching'
git config --global core.editor     'vim'

# ================================================================
# Account Configuration
# ================================================================

[ -e $STAGE/auth ] && ( set -e
    cd
    mkdir -p .ssh
    cd .ssh
    rm -rvf id_{ecdsa,rsa}{,.pub}
    ssh-keygen -N '' -f id_ecdsa -qt ecdsa -b 521 &
    ssh-keygen -N '' -f id_rsa -qt rsa -b 8192 &
    wait
    cd $SCRATCH

    # ------------------------------------------------------------

    cd /etc/openldap
    for i in 'BASE' 'URI' 'TLS_CACERT' 'TLS_REQCERT'; do :
        if [ `grep '^[[:space:]#]*'$i'[[:space:]]' ldap.conf | wc -l` -ne 1 ]; then
            sed 's/^[[:space:]#]*'$i'[[:space:]].*//' ldap.conf > .ldap.conf
            mv -f .ldap.conf ldap.conf
            echo '#'$i' ' >> ldap.conf
        fi
    done
    cat ldap.conf                                                                                               \
    | sed 's/^[[:space:]#]*\(BASE[[:space:]][[:space:]]*\).*/\1dc=codingcafe,dc=org/'                           \
    | sed 's/^[[:space:]#]*\(URI[[:space:]][[:space:]]*\).*/\1ldap:\/\/ldap.codingcafe.org/'                    \
    | sed 's/^[[:space:]#]*\(TLS_CACERT[[:space:]][[:space:]]*\).*/\1\/etc\/pki\/tls\/certs\/ca-bundle.crt/'    \
    | sed 's/^[[:space:]#]*\(TLS_REQCERT[[:space:]][[:space:]]*\).*/\1demand/'                                  \
    > .ldap.conf
    mv -f .ldap.conf ldap.conf
    cd $SCRATCH

    # ------------------------------------------------------------

    # May fail at the first time in unprivileged docker due to domainname change.
    for i in $($IS_CONTAINER && echo true) false; do :
        authconfig                                                                          \
            --enable{sssd{,auth},ldap{,auth,tls},locauthorize,cachecreds,mkhomedir}         \
            --disable{cache,md5,nis,rfc2307bis}                                             \
            --ldapserver=ldap://ldap.codingcafe.org                                         \
            --ldapbasedn=dc=codingcafe,dc=org                                               \
            --passalgo=sha512                                                               \
            --smbsecurity=user                                                              \
            --update                                                                        \
        || $i
    done

    systemctl daemon-reload || $IS_CONTAINER
    for i in sssd; do :
        systemctl enable $i
        systemctl start $i || $IS_CONTAINER
    done
) && rm -rvf $STAGE/auth
sync || true

. pkgs/slurm.sh
. pkgs/openmpi.sh
. pkgs/nagios.sh
. pkgs/shadowsocks.sh
. pkgs/texlive.sh
. pkgs/cmake.sh
. pkgs/llvm.sh
. pkgs/boost.sh
. pkgs/jemalloc.sh
. pkgs/gflags.sh
. pkgs/glog.sh
. pkgs/protobuf.sh
. pkgs/leveldb.sh
. pkgs/lmdb.sh
. pkgs/openblas.sh
. pkgs/opencv.sh
. pkgs/rocksdb.sh
. pkgs/caffe.sh
. pkgs/caffe2.sh

# ================================================================
# Cleanup
# ================================================================

ccache -C &
ldconfig &
cd
# $IS_CONTAINER || umount $SCRATCH
rm -rvf $SCRATCH
wait

echo
echo
echo '================================================================'
date
echo '----------------------------------------------------------------'
echo '                           Completed!                           '
$IS_CONTAINER && \
echo '                       -- In Container --                       '
echo '----------------------------------------------------------------'
echo -n '| Node     | '
uname -no
echo -n '| Kernel   | '
uname -sr
echo -n '| Platform | '
uname -m
echo '----------------------------------------------------------------'
df -h --sync --output=target,fstype,size,used,avail,pcent,source | sed 's/^/| /'
echo '================================================================'

# ----------------------------------------------------------------

trap - SIGTERM SIGINT EXIT

truncate -s 0 .bash_history
