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
    [ $# -gt 0 ] && touch $@ || touch repo pkg auth nagios ss tex llvm boost jemalloc caffe2
    sync || true
    cd $SCRATCH
    mv -vf $(dirname $STAGE)/.$(basename $STAGE) $STAGE
)

# ================================================================
# YUM Configuration
# ================================================================

[ -e $STAGE/repo ] && ( set -e
    until yum install -y yum-utils{,-*}; do echo 'Retrying'; done

    yum-config-manager --setopt=tsflags= --save

    [ -f $RPM_CACHE_REPO ] || yum-config-manager --add-repo https://repo.codingcafe.org/cache/el/7/cache.repo

    echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}{{base,updates,extras,centosplus}{,-source},base-debuginfo}\; | sed 's/%/ /g' | bash

    until yum install -y yum-plugin-{priorities,fastestmirror} curl kernel-headers; do echo 'Retrying'; done

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

# ================================================================
# Install Packages
# ================================================================

[ -e $STAGE/pkg ] && ( set -e
    until yum install -y $([ -f $RPM_CACHE_REPO ] && echo "--disableplugin=axelget,fastestmirror")    \
                                                                \
    qpid-cpp-client{,-*}                                        \
    {gcc,distcc,ccache}{,-*}                                    \
    java-1.8.0-openjdk{,-*}                                     \
    octave{,-*}                                                 \
    {gdb,valgrind,perf,{l,s}trace}{,-*}                         \
    {make,ninja-build,confu,cmake{,3},autoconf,libtool}{,-*}    \
    {ant,maven}{,-*}                                            \
    {git,subversion,mercurial}{,-*}                             \
    doxygen{,-*}                                                \
    swig{,-*}                                                   \
                                                                \
    vim{,-*}                                                    \
    dos2unix{,-*}                                               \
                                                                \
    {bash,fish,zsh,mosh,tmux}{,-*}                              \
    {bc,sed,man,pv}{,-*}                                        \
    {parallel,jq}{,-*}                                          \
    {tree,lsof}{,-*}                                            \
    {telnet,tftp,rsh}{,-debuginfo}                              \
    {f,h,if,io,latency,power,tip}top{,-*}                       \
    procps-ng{,-*}                                              \
    glances{,-*}                                                \
    {wget,axel,curl,net-tools}{,-*}                             \
    {f,tc,dhc,libo,io}ping{,-*}                                 \
    hping3{,-*}                                                 \
    {traceroute,mtr,rsync,tcpdump,whois,net-snmp}{,-*}          \
    torsocks{,-*}                                               \
    {bridge-,core,crypto-,elf,find,ib,ip}utils{,-*}             \
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
    yum-utils{,-*}                                              \
    createrepo{,_c}{,-*}                                        \
                                                                \
    ncurses{,-*}                                                \
    hwloc{,-*}                                                  \
    icu{,-*}                                                    \
    {glibc{,-devel},libgcc}{,.i686}                             \
    {gmp,mpfr,libmpc}{,-*}                                      \
    gperftools{,-*}                                             \
    lib{jpeg-turbo,tiff,png,glvnd}{,-*}                         \
    {zlib,libzip,{,p}xz,snappy}{,-*}                            \
    lib{telnet,ssh{,2},curl,aio,ffi,edit,icu,xslt}{,-*}         \
    boost{,-*}                                                  \
    {flex,cups,bison,antlr}{,-*}                                \
    open{blas,cv,ssl,ssh,ldap}{,-*}                             \
    eigen3{,-*}                                                 \
    {libsodium,mbedtls}{,-*}                                    \
    {gflags,glog,gtest,protobuf}{,-*}                           \
    {redis,hiredis}{,-*}                                        \
    ImageMagick{,-*}                                            \
    docbook{,5,2X}{,-*}                                         \
    nagios{,selinux,devel,debuginfo,-plugins-all}               \
    nrpe,nsca                                                   \
    {collectd,rrdtool,pnp4nagios}{,-*}                          \
    cuda                                                        \
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

    do echo 'Retrying'; done

    # TODO: Fix the following issue:
    #       LLVM may select the wrong gcc toolchain without libgcc_s integrated.
    #       The correct choice is x86_64-redhat-linux instead of x86_64-linux-gnu.
    yum remove -y gcc-x86_64-linux-gnu

    yum autoremove -y
    yum clean packages

    parallel --will-cite < /dev/null

    # ------------------------------------------------------------

    until yum install -y --skip-broken $([ -f $RPM_CACHE_REPO ] && echo "--disableplugin=axelget,fastestmirror") libreoffice; do echo 'Retrying'; done

    yum autoremove -y
    yum clean packages

    # ------------------------------------------------------------

    for i in anaconda perl python{,2,34} qt5 ruby; do :
        until yum install -y --skip-broken $([ -f $RPM_CACHE_REPO ] && echo "--disableplugin=axelget,fastestmirror") $i{,-*}; do echo 'Retrying'; done
        yum autoremove -y
        yum clean packages
    done

    # ------------------------------------------------------------

    until yum install -y --skip-broken *-fonts; do echo 'Retrying'; done

    until yum install -y "https://downloads.sourceforge.net/project/mscorefonts2/rpms/$(
        curl -sSL https://sourceforge.net/projects/mscorefonts2/files/rpms/                                         \
        | sed -n 's/.*\(msttcore-fonts-installer-\([0-9]*\).\([0-9]*\)-\([0-9]*\).noarch.rpm\).*/\2 \3 \4 \1/p'     \
        | sort -n | tail -n1 | cut -d' ' -f4 -
    )"; do echo 'Retrying'; done

    yum autoremove -y
    yum clean packages

    fc-cache -fv

    # ------------------------------------------------------------

    until yum update -y --skip-broken; do echo 'Retrying'; done
    yum update -y || true

    $IS_CONTAINER || package-cleanup --oldkernels --count=2
    yum autoremove -y
    yum clean all

    curl -sSL https://repo.codingcafe.org/cudnn/$(curl -sSL https://repo.codingcafe.org/cudnn | sed -n 's/.*href="\(.*linux-x64.*\)".*/\1/p') | tar -zxvf - -C /usr/local/
) && rm -rvf $STAGE/pkg
sync || true

# ================================================================
# Git Mirror
# ================================================================

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

    echo 'net.ipv4.tcp_fastopen = 3' > /etc/sysctl.d/tcp-fast-open.conf
    sysctl -p
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
    rm -rvf $SCRATCH/install-tl-*
) && rm -rvf $STAGE/tex
sync || true

# ================================================================
# Compile LLVM
# ================================================================

for i in llvm-{gcc,clang}; do
    [ -e $STAGE/$i ] && ( set -e
        export LLVM_MIRROR=$GIT_MIRROR/llvm-mirror
        export LLVM_GIT_TAG=release_40

        cd $SCRATCH
        until git clone $LLVM_MIRROR/llvm.git; do echo 'Retrying'; done
        cd llvm
        git checkout $LLVM_GIT_TAG
        cd tools
        until git clone $LLVM_MIRROR/polly.git; do echo 'Retrying'; done &
        until git clone $LLVM_MIRROR/lldb.git; do echo 'Retrying'; done &
        until git clone $LLVM_MIRROR/lld.git; do echo 'Retrying'; done &
        until git clone $LLVM_MIRROR/clang.git; do echo 'Retrying'; done
        cd clang
        git checkout $LLVM_GIT_TAG
        cd tools
        until git clone $LLVM_MIRROR/clang-tools-extra.git extra; do echo 'Retrying'; done
        cd extra
        git checkout $LLVM_GIT_TAG &
        wait
        cd ../../../polly
        git checkout $LLVM_GIT_TAG &
        cd ../lldb
        git checkout $LLVM_GIT_TAG &
        cd ../lld
        git checkout $LLVM_GIT_TAG &
        cd ../../projects
        until git clone $LLVM_MIRROR/compiler-rt.git; do echo 'Retrying'; done &
        until git clone $LLVM_MIRROR/libunwind.git; do echo 'Retrying'; done &
        until git clone $LLVM_MIRROR/libcxx.git; do echo 'Retrying'; done &
        until git clone $LLVM_MIRROR/libcxxabi.git; do echo 'Retrying'; done &
        until git clone $LLVM_MIRROR/openmp.git; do echo 'Retrying'; done &
        wait
        cd compiler-rt
        git checkout $LLVM_GIT_TAG &
        cd ../libunwind
        git checkout $LLVM_GIT_TAG &
        cd ../libcxx
        git checkout $LLVM_GIT_TAG &
        cd ../libcxxabi
        git checkout $LLVM_GIT_TAG &
        cd ../openmp
        git checkout $LLVM_GIT_TAG &
        cd ../..
        wait

        # ------------------------------------------------------------

        ccache -C &
        rm -rvf $SCRATCH/llvm/build
        mkdir -p $_
        cd $_
        wait

        # ------------------------------------------------------------

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
        
        [ $i = llvm-gcc ] && cmake3                 \
            -DLLVM_ENABLE_CXX1Y=ON                  \
            $LLVM_COMMON_ARGS

        [ $i = llvm-clang ] &&                      \
        CC='clang'                                  \
        CXX='clang++'                               \
        LD=$(which ld.lld)                          \
        cmake3                                      \
            -DENABLE_X86_RELAX_RELOCATIONS=ON       \
            -DLIBCXX_USE_COMPILER_RT=ON             \
            -DLIBCXXABI_USE_COMPILER_RT=ON          \
            -DLIBCXXABI_USE_LLVM_UNWINDER=ON        \
            -DLIBUNWIND_USE_COMPILER_RT=ON          \
            -DLLVM_ENABLE_LIBCXX=ON                 \
            -DLLVM_ENABLE_LLD=ON                    \
            -DLLVM_ENABLE_LTO=OFF                   \
            -DLLVM_ENABLE_MODULE_DEBUGGING=ON       \
            -DLLVM_ENABLE_MODULES=OFF               \
            -DLLVM_ENABLE_CXX1Y=ON                  \
            -DLLVM_ENABLE_CXX1Z=OFF                 \
            $LLVM_COMMON_ARGS

        # ------------------------------------------------------------

        time cmake3 --build . --target install

        ldconfig &
        cd
        rm -rvf $SCRATCH/llvm
        wait
    ) && rm -rvf $STAGE/$i
    sync || true
done

# ================================================================
# Compile Boost
# ================================================================

[ -e $STAGE/boost ] && ( set -e
    cd $SCRATCH
    ccache -C &
    axel -an 20 https://dl.bintray.com/boostorg/release/1.65.0/source/boost_1_65_0.tar.bz2
    wait
    tar -xvf boost*.tar.bz2
    cd boost*/
    # CC=$(which clang) CXX=$(which clang++) LD=$(which lld) ./bootstrap.sh --with-toolset=clang
    ./bootstrap.sh
    # CC=$(which clang) CXX=$(which clang++) LD=$(which lld) ./b2 cxxflags="-std=c++11 -stdlib=libc++ -fuse-ld=lld" linkflags="-stdlib=libc++" -aj`nproc --all` install
    ./b2 -aj`nproc` install

    # ------------------------------------------------------------

    ldconfig
    cd
    rm -rvf $SCRATCH/boost*
) && rm -rvf $STAGE/boost
sync || true

# ================================================================
# Compile Jemalloc
# ================================================================

[ -e $STAGE/jemalloc ] && ( set -e
    cd $SCRATCH
    until git clone $GIT_MIRROR/jemalloc/jemalloc.git; do echo 'Retrying'; done
    cd jemalloc
    git checkout `git tag -l '[0-9\.]*' | tail -n1`

    # ------------------------------------------------------------

    ccache -C
    CC='clang -fuse-ld=lld' LD=$(which lld) ./autogen.sh --with-jemalloc-prefix="" --enable-prof --enable-prof-libunwind
    time make -j`nproc` dist
    time LD=$(which lld) make -j`nproc`
    time make -j`nproc` install

    # ------------------------------------------------------------

    ldconfig
    cd
    rm -rvf $SCRATCH/jemalloc
) && rm -rvf $STAGE/jemalloc
sync || true

# ================================================================
# Compile Caffe2
# ================================================================

[ -e $STAGE/caffe2 ] && ( set -e
    cd $SCRATCH
    until git clone --recursive $GIT_MIRROR/caffe2/caffe2.git; do echo 'Retrying'; done
    cd caffe2

    # ------------------------------------------------------------

    mkdir -p build
    cd $_

    CC='clang -fuse-ld=lld'                             \
    CXX='clang++ -fuse-ld=lld'                          \
    LD=$(which lld)                                     \
    cmake3                                              \
        -DCMAKE_BUILD_TYPE=Release                      \
        -DBENCHMARK_ENABLE_LTO=ON                       \
        -DBENCHMARK_USE_LIBCXX=ON                       \
        -DBLAS=OpenBLAS                                 \
        -DBUILD_BENCHMARK=OFF                           \
        -DBUILD_GTEST=ON                                \
        -DCAFFE2_NINJA_COMMAND=$(which ninja-build)     \
        ..

    time cmake3 --build . --target install
    ldconfig
    cd
    rm -rvf $SCRATCH/caffe2
) && rm -rvf $STAGE/caffe2
sync || true

# ================================================================
# Cleanup
# ================================================================

# $IS_CONTAINER || umount $SCRATCH
rm -rvf $SCRATCH
cd

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
