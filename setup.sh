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
    [ $# -gt 0 ] && touch $@ || touch repo pkg auth slurm ompi nagios ss tex llvm boost jemalloc rocksdb caffe caffe2
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
    lib{jpeg-turbo,tiff,png,glvnd,gomp}{,-*}                    \
    {bzip2,zlib,libzip,{,lib}zstd,lz4,{,p}xz,snappy}{,-*}       \
    lib{telnet,ssh{,2},curl,aio,ffi,edit,icu,xslt}{,-*}         \
    boost{,-*}                                                  \
    {flex,cups,bison,antlr}{,-*}                                \
    open{blas,cv,ssl,ssh,ldap}{,-*}                             \
    {atlas,eigen3}{,-*}                                         \
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
    https://github.com/NVIDIA/nvidia-docker/releases/download/v1.0.1/nvidia-docker-1.0.1-1.x86_64.rpm   \
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
    devtoolset-{3,4,6}                                          \

    do echo 'Retrying'; done

    # TODO: Fix the following issue:
    #       LLVM may select the wrong gcc toolchain without libgcc_s integrated.
    #       The correct choice is x86_64-redhat-linux instead of x86_64-linux-gnu.
    yum remove -y gcc-x86_64-linux-gnu

    yum autoremove -y
    yum clean packages

    parallel --will-cite < /dev/null

    systemctl enable nvidia-docker || $IS_CONTAINER
    systemctl restart nvidia-docker || $IS_CONTAINER

    # For nvidia-docker
    $IS_CONTAINER && echo /usr/local/nvidia/lib{,64} | xargs -n1 >> /etc/ld.so.conf.d/nvidia.conf
    ldconfig

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
            export HTTPS_PROXY=$HTTP_PROXY
            export http_proxy=$HTTP_PROXY
            export https_proxy=$HTTPS_PROXY

            curl -sSL https://repo.codingcafe.org/nvidia/cudnn/$(curl -sSL https://repo.codingcafe.org/nvidia/cudnn | sed -n 's/.*href="\(.*linux-x64.*\)".*/\1/p' | sort | tail -n1) | tar -zxvf - -C /usr/local/
        else
            curl -sSL https://developer.download.nvidia.com/compute/redist/cudnn/v7.0.3/cudnn-9.0-linux-x64-v7.tgz | tar -zxvf - -C /usr/local/
        fi
        curl -sSL https://repo.codingcafe.org/nvidia/nccl/$(curl -sSL https://repo.codingcafe.org/nvidia/nccl | sed -n 's/.*href="\(.*amd64.*\)".*/\1/p' | sort | tail -n1) | tar -Jxvf - --strip-components=1 -C /usr/local/
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

# ================================================================
# SLURM
# ================================================================

[ -e $STAGE/slurm ] && ( set -e
    cd $SCRATCH

    git clone $GIT_MIRROR/SchedMD/slurm.git
    cd slurm
    git checkout $(git tag | sed -n '/^slurm-[0-9\-]*$/p' | sort -V | tail -n1)

    . scl_source enable devtoolset-6

    for i in $(sed -n 's/^[[:space:]]*\(.*:\).* META .*/\1/p' slurm.spec); do
        sed -i "s/^\([[:space:]]*$i[[:space:]]*\).* META .*/\1"$(sed -n "s/[[:space:]]*$i[[:space:]]*\(.*\)/\1/p" META | head -n1)"/" slurm.spec
    done

    export SLURM_NAME=$(for i in Name Version Release; do
        sed -n "s/^[[:space:]]*$i:[[:space:]]*\(.*\)/\1/p" META | head -n1
    done | xargs | sed 's/[[:space:]][[:space:]]*/-/g')

    export SLURM_EXT=$(sed -n "s/^[[:space:]]*Source:[^\.]*\(.*\)/\1/p" slurm.spec | head -n1)

    export SLURM_TAR=$SLURM_NAME$SLURM_EXT

    cd ..
    mkdir -p $SLURM_NAME
    cp -rf slurm/* $_/
    tar -acvf $SLURM_TAR $SLURM_NAME
    rm -rf $SCRATCH/$SLURM_NAME

    rpmbuild -ta $SLURM_TAR --with lua --with multiple_slurmd --with mysql --with openssl

    rm -rf $SCRATCH/slurm*

    yum install $HOME/rpmbuild/RPMS/$(uname -i)/slurm{,-*}.rpm
    rm -rf $HOME/rpmbuild
) && rm -rvf $STAGE/slurm
sync || true

# ================================================================
# OpenMPI
# ================================================================

[ -e $STAGE/opmi ] && ( set -e
    cd $SCRATCH

    git clone $GIT_MIRROR/open-mpi/ompi.git
    cd ompi
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

    . scl_source enable devtoolset-6

    ./autogen.pl
    ./configure                             \
        --enable-mpi-cxx                    \
        --enable-mpi-ext                    \
        --enable-mpi-java                   \
        --enable-mpirun-prefix-by-default   \
        --enable-sparse-groups              \
        --enable-static                     \
        --prefix=/usr/local/openmpi         \
        --with-cuda                         \
        --with-sge                          \
        --with-slurm

    make -j$(nproc)
    make -j install

    cd
    rm -rf $SCRATCH/opmi
) && rm -rvf $STAGE/opmi
sync || true

# ================================================================
# Nagios
# ================================================================

[ -e $STAGE/nagios ] && ( set -e
    setsebool -P daemons_enable_cluster_mode 1 || $IS_CONTAINER

    mkdir -p $SCRATCH/nagios-selinux
    cd $_

    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF > nagios-statusjsoncgi.te
module nagios-statusjsoncgi 1.0;
require {
  type nagios_script_t;
  type nagios_spool_t;
  class file { getattr read open };
}
allow nagios_script_t nagios_spool_t:file { getattr read open };
EOF
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    checkmodule -M -m -o nagios-statusjsoncgi.{mod,te}
    semodule_package -m nagios-statusjsoncgi.mod -o nagios-statusjsoncgi.pp
    semodule -i $_

    systemctl daemon-reload || $IS_CONTAINER
    for i in nagios; do :
    #     systemctl enable $i
    #     systemctl start $i || $IS_CONTAINER
    done

    cd
    rm -rvf $SCRATCH/nagios-selinux
) && rm -rvf $STAGE/nagios
sync || true

# ================================================================
# Shadowsocks
# ================================================================

[ -e $STAGE/ss ] && ( set -e
    pip install $GIT_MIRROR/shadowsocks/shadowsocks/$([ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ] && echo 'repository/archive.zip?ref=master' || echo 'archive/master.zip')

    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF > /usr/lib/systemd/system/shadowsocks.service
[Unit]
Description=Shadowsocks daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ssserver -p 8388 -k sensitive_password_removed -m aes-256-gcm --fast-open
User=nobody

[Install]
WantedBy=multi-user.target
EOF
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF > /usr/lib/systemd/system/shadowsocks-client.service
[Unit]
Description=Shadowsocks client daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/sslocal -l 1080 -s sensitive_url_removed -p 8388 -k sensitive_password_removed -m aes-256-gcm --fast-open
User=nobody

[Install]
WantedBy=multi-user.target
EOF
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    systemctl daemon-reload || $IS_CONTAINER
    for i in shadowsocks{,-client}; do :
        systemctl enable $i
        systemctl start $i || $IS_CONTAINER
    done

    # ------------------------------------------------------------

    modprobe -a tcp_htcp tcp_hybla
    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF > /etc/modules-load.d/90-shadowsocks.conf
tcp_htcp
tcp_hybla
EOF
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF > /etc/sysctl.d/90-shadowsocks.conf
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000

net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = htcp
EOF
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    sysctl --system
    # sslocal -s sensitive_url_removed -p 8388 -k sensitive_password_removed -m aes-256-gcm --fast-open -d restart
) && rm -rvf $STAGE/ss
sync || true

# ================================================================
# Install TeX Live
# ================================================================

[ -e $STAGE/tex ] && ( set -e set -e
    export TEXLIVE_MIRROR=https://repo.codingcafe.org/CTAN/systems/texlive/tlnet

    cd $SCRATCH
    curl -sSL $TEXLIVE_MIRROR/install-tl-unx.tar.gz | tar -zxvf -
    cd install-tl-*
    ./install-tl --version

    ./install-tl --repository $TEXLIVE_MIRROR --profile <(
    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF
selected_scheme scheme-full
instopt_adjustpath 1
EOF
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    )

    cd
    rm -rf $SCRATCH/install-tl-*
) && rm -rvf $STAGE/tex
sync || true

# ================================================================
# Compile LLVM
# ================================================================

for i in llvm-{gcc,clang}; do
    [ -e $STAGE/$i ] && ( set -e
        export LLVM_MIRROR=$GIT_MIRROR/llvm-mirror
        export LLVM_GIT_TAG=release_50

        cd $SCRATCH

        ( set -e
            echo "Retriving LLVM "$LLVM_GIT_TAG"..."
            until git clone --branch $LLVM_GIT_TAG $LLVM_MIRROR/llvm.git; do echo 'Retrying'; done
            cd llvm
            cd projects
            for i in compiler-rt lib{cxx{,abi},unwind} openmp; do
                until git clone --branch $LLVM_GIT_TAG $LLVM_MIRROR/$i.git; do echo 'Retrying'; done &
            done
            cd ../tools
            for i in lld lldb polly; do
                until git clone --branch $LLVM_GIT_TAG $LLVM_MIRROR/$i.git; do echo 'Retrying'; done &
            done
            until git clone --branch $LLVM_GIT_TAG $LLVM_MIRROR/clang.git; do echo 'Retrying'; done
            cd clang/tools
            until git clone --branch $LLVM_GIT_TAG $LLVM_MIRROR/clang-tools-extra.git extra; do echo 'Retrying'; done
            wait
        )

        # ------------------------------------------------------------

        mkdir -p llvm/build
        cd $_

        . scl_source enable devtoolset-6
        ccache -C

        export LLVM_COMMON_ARGS="
            -DCLANG_ANALYZER_BUILD_Z3=OFF
            -DCLANG_DEFAULT_CXX_STDLIB=libc++
            -DCMAKE_BUILD_TYPE=Release
            -DCMAKE_INSTALL_PREFIX='\usr\'
            -DCMAKE_VERBOSE_MAKEFILE=ON
            -DLIBCLANG_BUILD_STATIC=ON
            -DLIBCXX_CONFIGURE_IDE=ON
            -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON
            -DLIBOMP_OMPT_SUPPORT=ON
            -DLIBOMP_STATS=OFF
            -DLIBOMP_TSAN_SUPPORT=ON
            -DLIBOMP_USE_HWLOC=ON
            -DLIBOMP_USE_STDCPPLIB=ON
            -DLIBUNWIND_ENABLE_CROSS_UNWINDING=ON
            -DLLDB_DISABLE_PYTHON=ON
            -DLLVM_BUILD_LLVM_DYLIB=ON
            -DLLVM_CCACHE_BUILD=ON
            -DLLVM_ENABLE_EH=ON
            -DLLVM_ENABLE_FFI=ON
            -DLLVM_ENABLE_RTTI=ON
            -DLLVM_INSTALL_UTILS=ON
            -DLLVM_LINK_LLVM_DYLIB=ON
            -DLLVM_OPTIMIZED_TABLEGEN=ON
            -DPOLLY_ENABLE_GPGPU_CODEGEN=ON
            -G Ninja
            .."
        
        if [ $i = llvm-gcc ]; then
            cmake3                                  \
                -DLLVM_ENABLE_CXX1Y=ON              \
                $LLVM_COMMON_ARGS
        else
            CC='clang'                              \
            CXX='clang++'                           \
            LD=$(which ld.lld)                      \
            cmake3                                  \
                -DENABLE_X86_RELAX_RELOCATIONS=ON   \
                -DLIBCXX_USE_COMPILER_RT=ON         \
                -DLIBCXXABI_USE_COMPILER_RT=ON      \
                -DLIBCXXABI_USE_LLVM_UNWINDER=ON    \
                -DLIBOMP_ENABLE_SHARED=OFF          \
                -DLIBUNWIND_USE_COMPILER_RT=ON      \
                -DLLVM_ENABLE_LIBCXX=ON             \
                -DLLVM_ENABLE_LLD=ON                \
                -DLLVM_ENABLE_LTO=OFF               \
                -DLLVM_ENABLE_CXX1Y=ON              \
                $LLVM_COMMON_ARGS
        fi

        # ------------------------------------------------------------

        # time cmake3 --build . --target dist
        # time cmake3 --build . --target dist-check
        # time cmake3 --build . --target rpm
        time cmake3 --build . --target install

        ldconfig &
        ccache -C &
        cd
        rm -rf $SCRATCH/llvm
        wait
    ) && rm -rvf $STAGE/$i
    sync || true
done

# ================================================================
# Compile Boost
# ================================================================

[ -e $STAGE/boost ] && ( set -e
    cd $SCRATCH

    if [ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ]; then
        export HTTP_PROXY=proxy.codingcafe.org:8118
        export HTTPS_PROXY=$HTTP_PROXY
        export http_proxy=$HTTP_PROXY
        export https_proxy=$HTTPS_PROXY
    fi

    mkdir -p boost
    cd $_
    curl -sSL https://dl.bintray.com/boostorg/release/1.65.1/source/boost_1_65_1.tar.bz2 | tar -jxvf - --strip-components=1

    . scl_source enable devtoolset-6
    ./bootstrap.sh
    ./b2 -aj`nproc` install

    # ------------------------------------------------------------

    ldconfig &
    ccache -C &
    cd
    rm -rf $SCRATCH/boost
    wait
) && rm -rvf $STAGE/boost
sync || true

# ================================================================
# Compile Jemalloc
# ================================================================

[ -e $STAGE/jemalloc ] && ( set -e
    cd $SCRATCH
    until git clone $GIT_MIRROR/jemalloc/jemalloc.git; do echo 'Retrying'; done
    cd jemalloc
    git checkout $(git tag | sed -n '/^[0-9\.]*$/p' | sort -V | tail -n1)

    # ------------------------------------------------------------

    . scl_source enable devtoolset-6
    ./autogen.sh --with-jemalloc-prefix="" --enable-{prof,xmalloc}
    time make -j$(nproc) dist
    time make -j$(nproc)
    time make -j$(nproc) install

    # ------------------------------------------------------------

    echo '/usr/local/lib' > /etc/ld.so.conf.d/jemalloc.conf
    ldconfig &
    ccache -C &
    cd
    rm -rf $SCRATCH/jemalloc
    wait
) && rm -rvf $STAGE/jemalloc
sync || true

# ================================================================
# Compile RocksDB
# ================================================================

[ -e $STAGE/rocksdb ] && ( set -e
    cd $SCRATCH

    pip install -U git+$GIT_MIRROR/Maratyszcza/{confu,PeachPy}.git

    . scl_source enable devtoolset-6

    until git clone $GIT_MIRROR/facebook/rocksdb.git; do echo 'Retrying'; done
    cd rocksdb
    git checkout $(git tag | sed -n '/^v[0-9\.]*$/p' | sort -V | tail -n1)

#     mkdir -p build
#     cd $_
#     ( set -e
#         cmake3                                  \
#             -G Ninja                            \
#             -DCMAKE_BUILD_TYPE=RelWithDebInfo   \
#             -DCMAKE_VERBOSE_MAKEFILE=ON         \
#             -DWITH_ASAN=ON                      \
#             -DWITH_BZ2=ON                       \
#             -DWITH_JEMALLOC=ON                  \
#             -DWITH_LIBRADOS=ON                  \
#             -DWITH_LZ4=ON                       \
#             -DWITH_SNAPPY=ON                    \
#             -DWITH_TSAN=ON                      \
#             _DWITH_UBSAN=ON                     \
#             -DWITH_ZLIB=ON                      \
#             -DWITH_ZSTD=ON                      \
#             ..
# 
#         time cmake3 --build . --target install
#     )

    time make -j$(nproc) static_lib
    # time make -j install
    time make -j$(nproc) shared_lib
    # time make -j install-shared
    time make -j package

    yum install -y package/rocksdb-*.rpm

    ccache -C &
    cd
    rm -rf $SCRATCH/rocksdb
    wait
) && rm -rvf $STAGE/rocksdb
sync || true

# ================================================================
# Compile Caffe
# ================================================================

[ -e $STAGE/caffe ] && ( set -e
    cd $SCRATCH

    until git clone $GIT_MIRROR/BVLC/caffe.git; do echo 'Retrying'; done
    cd caffe

    # ------------------------------------------------------------

    mkdir -p build
    cd $_
    ( set -e
        . scl_source enable devtoolset-6

        cmake3                                  \
            -G"Unix Makefiles"                  \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo   \
            -DCMAKE_VERBOSE_MAKEFILE=ON         \
            -DBLAS=Open                         \
            -DUSE_NCCL=ON                       \
            ..

        time cmake3 --build . -- -j $(nproc)
        time cmake3 --build . --target test -- -j $(nproc)
        time cmake3 --build . --target install -- -j $(nproc)
    )

    ldconfig &
    ccache -C &
    cd
    rm -rf $SCRATCH/caffe
    wait
) && rm -rvf $STAGE/caffe
sync || true

# ================================================================
# Compile Caffe2
# ================================================================

[ -e $STAGE/caffe2 ] && ( set -e
    cd $SCRATCH

    # ------------------------------------------------------------

    until git clone $GIT_MIRROR/caffe2/caffe2.git; do echo 'Retrying'; done
    cd caffe2

    if [ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ]; then
        export HTTP_PROXY=proxy.codingcafe.org:8118
        export HTTPS_PROXY=$HTTP_PROXY
        export http_proxy=$HTTP_PROXY
        export https_proxy=$HTTPS_PROXY
        for i in Maratyszcza NVLabs NervanaSystems glog google nvidia; do
            sed -i "s/[^[:space:]]*:\/\/[^\/]*\/$i/$(sed 's/\//\\\//g' <<<$GIT_MIRROR )\/$i/" .gitmodules
        done
    fi

    git submodule init
    until git config --file .gitmodules --get-regexp path | cut -d' ' -f2 | parallel -j0 --ungroup --bar 'git submodule update --recursive {}'; do echo 'Retrying'; done

    echo "list(REMOVE_ITEM Caffe2_DEPENDENCY_LIBS cblas)" >> cmake/Dependencies.cmake

    # ------------------------------------------------------------

    mkdir -p build
    cd $_

    ( set -e
        . scl_source enable devtoolset-6

        ln -sf $(which ninja-build) /usr/bin/ninja

        export MPI_HOME=/usr/local/openmpi

        cmake3                                                  \
            -G"Unix Makefiles"                                  \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo                   \
            -DCMAKE_VERBOSE_MAKEFILE=ON                         \
            -DBENCHMARK_ENABLE_LTO=ON                           \
            -DBENCHMARK_USE_LIBCXX=OFF                          \
            -DBLAS=OpenBLAS                                     \
            -DBUILD_BENCHMARK=OFF                               \
            -DBUILD_GTEST=ON                                    \
            ..

        time cmake3 --build . -- -j$(nproc)
        time cmake3 --build . --target test || true
        time cmake3 --build . --target install -- -j

        rm -rf /usr/bin/ninja
    )

    for i in /usr/lib/python*/site-packages; do
    for j in caffe{,2}; do
        ln -sf /usr/local/$j $i/$j &
    done
    done

    echo '/usr/local/lib' > /etc/ld.so.conf.d/caffe2.conf
    ldconfig &
    ccache -C &
    cd
    rm -rf $SCRATCH/caffe2
    wait

    parallel -j0 --bar --line-buffer python -m caffe2.python.models.download -f -i {} :::   \
        bvlc_{alexnet,googlenet,reference_caffenet}                                         \
        finetune_flickr_style                                                               \
        squeezenet
) && rm -rvf $STAGE/caffe2
sync || true

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
