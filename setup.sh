#!/bin/bash

set -e

# ================================================================
# Environment Configuration
# ================================================================

export SCRATCH=/tmp/scratch

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

mkdir -p $SCRATCH
# mount -t tmpfs -o size=100% tmpfs $SCRATCH
cd $SCRATCH

# ================================================================
# YUM Configuration
# ================================================================

until yum install -y yum-utils{,-*}; do echo 'Retrying'; done

yum-config-manager --setopt=tsflags= --save

[ -f $RPM_CACHE_REPO ] || yum-config-manager --add-repo https://repo.codingcafe.org/cache/el/7/cache.repo

echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}{{base,updates,extras,centosplus}{,-source},base-debuginfo}\; | sed 's/%/ /g' | bash

until yum install -y yum-plugin-{priorities,fastestmirror} curl kernel-headers; do echo 'Retrying'; done

until yum install -y epel-release; do echo 'Retrying'; done
echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}epel{,-source,-debuginfo}\; | sed 's/%/ /g' | bash

until yum install -y yum-axelget; do echo 'Retrying'; done

# until yum install -y centos-release-scl{,-rh}; do echo 'Retrying'; done
# yum-config-manager --enable centos-sclo-{sclo,rh}-debuginfo

until yum update -y --skip-broken; do echo 'Retrying'; done
yum update -y || true
rpm -i $(
    curl -s https://developer.nvidia.com/cuda-downloads                     \
    | grep 'Linux/x86_64/CentOS/7/rpm (network)'                            \
    | head -n1                                                              \
    | sed "s/.*\('.*developer.download.nvidia.com\/[^\']*\.rpm'\).*/\1/"
) || true
# rpm -i "http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/`curl -s http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/ | sed -n 's/.*\(cuda-repo-rhel7-.*\.x86_64\.rpm\).*/\1/p' | sort | tail -n 1`"
echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}cuda\; | sed 's/%/ /g' | bash

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}docker-ce-stable{,-source,-debuginfo}\; | sed 's/%/ /g' | bash

curl -sSL https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.rpm.sh | bash
echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}runner_gitlab-ci-multi-runner{,-source}\; | sed 's/%/ /g' | bash

rm -rf /etc/yum.repos.d/gitlab_gitlab-ce.repo
curl -sSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | bash
echo yum-config-manager%--{disable%,enable%$([ -f $RPM_CACHE_REPO ] && echo 'cache-')}gitlab_gitlab-ce{,-source}\; | sed 's/%/ /g' | bash

until yum update -y --skip-broken; do echo 'Retrying'; done
yum update -y || true

# ================================================================
# Git Mirror
# ================================================================

until yum install -y $([ -f $RPM_CACHE_REPO ] && echo "--disableplugin=axelget,fastestmirror")    \
                                    \
{bc,sed}{,-*}                       \
{core,find,ip}utils{,-*}            \

do echo 'Retrying'; done

export GIT_MIRROR=$(
    for i in $(env | sed -n 's/^GIT_MIRROR_[^=]*=//p'); do
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

until yum remove -y             \
                                \
compat-qpid-cpp-client{,-*}     \

do echo 'Retrying'; done

# ----------------------------------------------------------------

until yum install -y $([ -f $RPM_CACHE_REPO ] && echo "--disableplugin=axelget,fastestmirror")    \
                                                            \
qpid-cpp-client{,-*}                                        \
{gcc,distcc,ccache}{,-*}                                    \
java-1.8.0-openjdk{,-*}                                     \
texlive{,-*}                                                \
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
{parallel,jq}{,-*}                                          \
{tree,lsof}{,-*}                                            \
{telnet,tftp,rsh}{,-debuginfo}                              \
{f,h,if,io,latency,power,tip}top{,-*}                       \
glances{,-*}                                                \
{wget,axel,curl,net-tools}{,-*}                             \
man{,-*}                                                    \
{f,tc,dhc,libo,io}ping{,-*}                                 \
hping3{,-*}                                                 \
{traceroute,mtr,rsync,tcpdump,whois,net-snmp}{,-*}          \
{elf,bridge-,ib}utils{,-*}                                  \
moreutils{,-debuginfo}                                      \
cyrus-imapd{,-*}                                            \
GeoIP{,-*}                                                  \
{device-mapper,lvm2}{,-*}                                   \
{d,sys}stat{,-*}                                            \
lm_sensors{,-*}                                             \
{{e2fs,btrfs-,xfs,ntfs}progs,xfsdump,nfs-utils}{,-*}        \
fuse{,-devel,-libs}                                         \
dd{,_}rescue{,-*}                                           \
{docker-ce,container-selinux}{,-*}                          \
yum-utils{,-*}                                              \
                                                            \
ncurses{,-*}                                                \
hwloc{,-*}                                                  \
icu{,-*}                                                    \
{gmp,mpfr,libmpc}{,-*}                                      \
gperftools{,-*}                                             \
lib{jpeg-turbo,tiff,png}{,-*}                               \
{zlib,libzip,{,p}xz,snappy}{,-*}                            \
lib{telnet,ssh{,2},curl,aio,ffi,edit,icu,xslt}{,-*}         \
boost{,-*}                                                  \
{flex,cups,bison,antlr}{,-*}                                \
open{blas,cv,ssl,ssh,ldap}{,-*}                             \
{gflags,glog,protobuf}{,-*}                                 \
ImageMagick{,-*}                                            \
docbook{,5,2X}{,-*}                                         \
cuda                                                        \
                                                            \
hdf5{,-*}                                                   \
{leveldb,lmdb}{,-*}                                         \
{mariadb,postgresql}{,-*}                                   \
                                                            \
{fio,filebench}{,-*}                                        \
                                                            \
{sudo,nss,sssd,authconfig}{,-*}                             \
                                                            \
gitlab-ci-multi-runner                                      \
                                                            \
youtube-dl                                                  \
                                                            \
libselinux{,-*}                                             \
policycoreutils{,-*}                                        \
se{troubleshoot,tools}{,-*}                                 \
selinux-policy{,-*}                                         \

do echo 'Retrying'; done

yum autoremove -y
yum clean packages

parallel --will-cite < /dev/null

# ----------------------------------------------------------------

until yum install -y --skip-broken $([ -f $RPM_CACHE_REPO ] && echo "--disableplugin=axelget,fastestmirror") libreoffice; do echo 'Retrying'; done

yum autoremove -y
yum clean packages

# ----------------------------------------------------------------

for i in qt5 perl python{,2,34} anaconda ruby; do
    until yum install -y --skip-broken $([ -f $RPM_CACHE_REPO ] && echo "--disableplugin=axelget,fastestmirror") $i{,-*}; do echo 'Retrying'; done
    yum autoremove -y
    yum clean packages
done

# ================================================================
# YUM Cleanup
# ================================================================

until yum update -y --skip-broken; do echo 'Retrying'; done
yum update -y || true

$IS_CONTAINER || package-cleanup --oldkernels --count=2
yum autoremove -y
yum clean all

# ================================================================
# Account Configuration
# ================================================================

cd
mkdir -p .ssh
cd .ssh
rm -rf id_{ecdsa,rsa}{,.pub}
ssh-keygen -N '' -f id_ecdsa -qt ecdsa -b 521 &
ssh-keygen -N '' -f id_rsa -qt rsa -b 8192 &
wait
cd

# ----------------------------------------------------------------

cd /etc/openldap
for i in 'BASE' 'URI' 'TLS_CACERT' 'TLS_REQCERT'; do
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
cd

# May fail at the first time in unprivileged docker due to domainname change.
for i in $($IS_CONTAINER && echo true) false; do
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
for i in sssd; do
    systemctl enable $i
    systemctl start $i || $IS_CONTAINER
done

# ================================================================
# Personalize
# ================================================================

git config --global user.name       'Tongliang Liao'
git config --global user.email      'xkszltl@gmail.com'
git config --global push.default    'matching'
git config --global core.editor     'vim'

# ================================================================
# Shadowsocks
# ================================================================

pip install $GIT_MIRROR/shadowsocks/shadowsocks/$([ $GIT_MIRROR == $GIT_MIRROR_CODINGCAFE ] && echo 'repository/archive.zip?ref=master' || echo 'archive/master.zip')

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
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
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

systemctl daemon-reload || $IS_CONTAINER
for i in shadowsocks; do
    systemctl enable $i
    systemctl start $i || $IS_CONTAINER
done

# ================================================================
# Compile LLVM
# ================================================================

export LLVM_MIRROR=$GIT_MIRROR/llvm-mirror

cd $SCRATCH
until git clone $LLVM_MIRROR/llvm.git; do echo 'Retrying'; done
cd llvm
git checkout release_40
cd tools
until git clone $LLVM_MIRROR/polly.git; do echo 'Retrying'; done &
until git clone $LLVM_MIRROR/lldb.git; do echo 'Retrying'; done &
until git clone $LLVM_MIRROR/lld.git; do echo 'Retrying'; done &
until git clone $LLVM_MIRROR/clang.git; do echo 'Retrying'; done
cd clang
git checkout release_40
cd tools
until git clone $LLVM_MIRROR/clang-tools-extra.git extra; do echo 'Retrying'; done
cd extra
git checkout release_40 &
wait
cd ../../../polly
git checkout release_40 &
cd ../lldb
git checkout release_40 &
cd ../lld
git checkout release_40 &
cd ../../projects
until git clone $LLVM_MIRROR/compiler-rt.git; do echo 'Retrying'; done &
until git clone $LLVM_MIRROR/libunwind.git; do echo 'Retrying'; done &
until git clone $LLVM_MIRROR/libcxx.git; do echo 'Retrying'; done &
until git clone $LLVM_MIRROR/libcxxabi.git; do echo 'Retrying'; done &
until git clone $LLVM_MIRROR/openmp.git; do echo 'Retrying'; done &
wait
cd compiler-rt
git checkout release_40 &
cd ../libunwind
git checkout release_40 &
cd ../libcxx
git checkout release_40 &
cd ../libcxxabi
git checkout release_40 &
cd ../openmp
git checkout release_40 &
cd ../..
wait

# ----------------------------------------------------------------

export LLVM_BUILD_TYPE=Release

mkdir -p $SCRATCH/llvm/build/$LLVM_BUILD_TYPE
cd $SCRATCH/llvm/build/$LLVM_BUILD_TYPE
ccache -C
cmake3 -G Ninja                             \
    -DCMAKE_BUILD_TYPE=$LLVM_BUILD_TYPE     \
    -DCMAKE_INSTALL_PREFIX='\usr\'          \
    -DCMAKE_VERBOSE_MAKEFILE=ON             \
    -DLIBCLANG_BUILD_STATIC=ON              \
    -DLIBCXX_CONFIGURE_IDE=ON               \
    -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON   \
    -DLIBOMP_OMPT_SUPPORT=ON                \
    -DLIBOMP_STATS=OFF                      \
    -DLIBOMP_TSAN_SUPPORT=ON                \
    -DLIBOMP_USE_HWLOC=ON                   \
    -DLIBOMP_USE_STDCPPLIB=ON               \
    -DLIBUNWIND_ENABLE_CROSS_UNWINDING=ON   \
    -DLLDB_DISABLE_PYTHON=ON                \
    -DLLVM_BUILD_LLVM_DYLIB=ON              \
    -DLLVM_CCACHE_BUILD=ON                  \
    -DLLVM_ENABLE_CXX1Y=ON                  \
    -DLLVM_ENABLE_EH=ON                     \
    -DLLVM_ENABLE_FFI=ON                    \
    -DLLVM_ENABLE_RTTI=ON                   \
    -DLLVM_INSTALL_UTILS=ON                 \
    -DLLVM_LINK_LLVM_DYLIB=ON               \
    -DLLVM_OPTIMIZED_TABLEGEN=ON            \
    -DPOLLY_ENABLE_GPGPU_CODEGEN=ON         \
    ../..
time cmake3 --build . --target install
ldconfig &
hash -r &
cd
rm -rf $SCRATCH/llvm/build &
wait

# ----------------------------------------------------------------

export LLVM_BUILD_TYPE=Release

mkdir -p $SCRATCH/llvm/build/$LLVM_BUILD_TYPE
cd $SCRATCH/llvm/build/$LLVM_BUILD_TYPE
ccache -C
CC='clang'                                  \
CXX='clang++ -stdlib=libc++'                \
LD=$(which lld)                             \
cmake3 -G Ninja                             \
    -DCMAKE_BUILD_TYPE=$LLVM_BUILD_TYPE     \
    -DCMAKE_INSTALL_PREFIX='\usr\'          \
    -DCMAKE_VERBOSE_MAKEFILE=ON             \
    -DCLANG_DEFAULT_CXX_STDLIB=libc++       \
    -DENABLE_X86_RELAX_RELOCATIONS=ON       \
    -DLIBCLANG_BUILD_STATIC=ON              \
    -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON   \
    -DLIBCXX_CONFIGURE_IDE=ON               \
    -DLIBCXXABI_USE_COMPILER_RT=ON          \
    -DLIBCXXABI_USE_LLVM_UNWINDER=ON        \
    -DLIBOMP_OMPT_SUPPORT=ON                \
    -DLIBOMP_STATS=OFF                      \
    -DLIBOMP_TSAN_SUPPORT=ON                \
    -DLIBOMP_USE_HWLOC=ON                   \
    -DLIBOMP_USE_STDCPPLIB=ON               \
    -DLIBUNWIND_ENABLE_CROSS_UNWINDING=ON   \
    -DLLDB_DISABLE_PYTHON=ON                \
    -DLLVM_BUILD_LLVM_DYLIB=ON              \
    -DLLVM_CCACHE_BUILD=ON                  \
    -DLLVM_ENABLE_CXX1Y=ON                  \
    -DLLVM_ENABLE_EH=ON                     \
    -DLLVM_ENABLE_FFI=ON                    \
    -DLLVM_ENABLE_LLD=ON                    \
    -DLLVM_ENABLE_LTO=OFF                   \
    -DLLVM_ENABLE_RTTI=ON                   \
    -DLLVM_INSTALL_UTILS=ON                 \
    -DLLVM_LINK_LLVM_DYLIB=ON               \
    -DLLVM_OPTIMIZED_TABLEGEN=ON            \
    -DPOLLY_ENABLE_GPGPU_CODEGEN=ON         \
    ../..
time cmake3 --build . --target install
ldconfig &
hash -r &
cd
rm -rf $SCRATCH/llvm/build &
wait

# ----------------------------------------------------------------

cd
rm -rf $SCRATCH/llvm

# ================================================================
# Compile Jemalloc
# ================================================================

cd $SCRATCH
until git clone $GIT_MIRROR/jemalloc/jemalloc.git; do echo 'Retrying'; done
cd jemalloc
git checkout `git tag -l '[0-9\.]*' | tail -n1`

# ----------------------------------------------------------------

ccache -C
CC='clang -fuse-ld=lld' LD=$(which lld) ./autogen.sh --with-jemalloc-prefix="" --enable-prof --enable-prof-libunwind
time make -j`nproc` dist
time LD=$(which lld) make -j`nproc`
time make -j`nproc` install

# ----------------------------------------------------------------

ldconfig
cd
rm -rf $SCRATCH/jemalloc

# ================================================================
# Compile Boost
# ================================================================

axel -an 20 -o $SCRATCH/boost.tar.bz2 https://downloads.sourceforge.net/project/boost/boost/1.64.0/boost_1_64_0.tar.bz2
cd $SCRATCH
tar -xvf boost.tar.bz2
rm -rf boost.tar.bz2
cd boost*/
ccache -C
# CC=$(which clang) CXX=$(which clang++) LD=$(which lld) ./bootstrap.sh --with-toolset=clang
./bootstrap.sh
# CC=$(which clang) CXX=$(which clang++) LD=$(which lld) ./b2 cxxflags="-std=c++11 -stdlib=libc++ -fuse-ld=lld" linkflags="-stdlib=libc++" -aj`nproc --all` install
./b2 -aj`nproc` install

# ----------------------------------------------------------------

ldconfig
cd
rm -rf $SCRATCH/boost*

# ================================================================
# Cleanup
# ================================================================

# umount $SCRATCH
rm -rf $SCRATCH
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

truncate -s 0 .bash_history
