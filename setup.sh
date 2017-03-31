#!/bin/bash

set -e

# ================================================================
# YUM Configuration
# ================================================================

yum-config-manager --setopt=tsflags= --save
until yum update -y --skip-broken; do echo 'Retrying'; done
yum update -y || true
until yum install -y curl; do echo 'Retrying'; done
rpm -i "http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/`curl -s http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/ | sed -n 's/.*\(cuda-repo-rhel7-.*\.x86_64\.rpm\).*/\1/p' | sort | tail -n 1`"
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.rpm.sh | bash
until yum install -y epel-release; do echo 'Retrying'; done
# until yum install -y centos-release-scl{,-rh}; do echo 'Retrying'; done
until yum update -y --skip-broken; do echo 'Retrying'; done
yum update -y || true
yum-config-manager --enable extras centosplus {base,epel}-debuginfo
# yum-config-manager --enable centos-sclo-{sclo,rh}-debuginfo
until yum update -y --skip-broken; do echo 'Retrying'; done
yum update -y || true

until yum install -y yum-{axelget,plugin-priorities}; do echo 'Retrying'; done

# ================================================================
# Install Packages
# ================================================================

until yum remove -y                                     \
                                                        \
compat-qpid-cpp-client{,-*}                             \

do echo 'Retrying'; done

# ----------------------------------------------------------------

until yum install -y                                    \
                                                        \
qpid-cpp-client{,-*}                                    \
{gcc,distcc,ccache}{,-*}                                \
java-1.8.0-openjdk{,-*}                                 \
texlive{,-*}                                            \
{gdb,valgrind,perf,{l,s}trace}{,-*}                     \
{make,cmake{,3},autoconf,libtool,ant,maven}{,-*}        \
{git,subversion,mercurial}{,-*}                         \
doxygen{,-*}                                            \
swig{,-*}                                               \
                                                        \
vim{,-*}                                                \
dos2unix{,-*}                                           \
                                                        \
{bash,fish,zsh,mosh,tmux}{,-*}                          \
{telnet,tftp,rsh}{,-debuginfo}                          \
{htop,glances}{,-*}                                     \
{wget,axel,curl,net-tools}{,-*}                         \
man{,-*}                                                \
{f,tc,dhc,libo,io}ping{,-*}                             \
hping3{,-*}                                             \
{traceroute,rsync,tcpdump}{,-*}                         \
{more,elf,ib}utils{,-*}                                 \
cyrus-imapd{,-*}                                        \
net-snmp{,-*}                                           \
GeoIP{,-*}                                              \
dstat{,-*}                                              \
lm_sensors{,-*}                                         \
{{e2fs,btrfs-,xfs,ntfs}progs,xfsdump,nfs-utils}{,-*}    \
dd{,_}rescue{,-*}                                       \
docker{,-*}                                             \
                                                        \
ncurses{,-*}                                            \
hwloc{,-*}                                              \
icu{,-*}                                                \
{gmp,mpfr,libmpc}{,-*}                                  \
lib{jpeg-turbo,tiff,png}{,-*}                           \
{zlib,libzip,{,p}xz,snappy}{,-*}                        \
lib{telnet,ssh{,2},curl,aio,ffi,edit,icu}{,-*}          \
boost{,-*}                                              \
{flex,cups,bison,antlr}{,-*}                            \
open{blas,cv,ssl,ssh,ldap}{,-*}                         \
{gflags,glog,protobuf}{,-*}                             \
ImageMagick{,-*}                                        \
cuda                                                    \
                                                        \
{hdf5}{,-*}                                             \
{leveldb,lmdb}{,-*}                                     \
{mariadb,postgresql}{,-*}                               \
                                                        \
{fio,filebench}{,-*}                                    \
                                                        \
{sudo,nss,sssd}{,-*}                                    \
                                                        \
gitlab-ci-multi-runner                                  \

do echo 'Retrying'; done

# ----------------------------------------------------------------

until yum install -y --skip-broken                      \
                                                        \
perl{,-*}                                               \
{python{,34},anaconda}{,-*}                             \
ruby{,-*}                                               \
qt5{,-*}                                                \

do echo 'Retrying'; done

# ----------------------------------------------------------------

until yum update -y --skip-broken; do echo 'Retrying'; done
yum update -y || true

# ================================================================
# Account Configuration
# ================================================================

cd
mkdir -p .ssh
cd .ssh
rm -rf id_{ecdsa,rsa}{,.pub}
ssh-keygen -N '' -f id_ecdsa -qt ecdsa -b 521
ssh-keygen -N '' -f id_rsa -qt rsa -b 8192
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
cat ldap.conf | \
sed 's/^[[:space:]#]*\(BASE[[:space:]][[:space:]]*\).*/\1dc=codingcafe,dc=org/' | \
sed 's/^[[:space:]#]*\(URI[[:space:]][[:space:]]*\).*/\1ldap:\/\/ldap.codingcafe.org/' | \
sed 's/^[[:space:]#]*\(TLS_CACERT[[:space:]][[:space:]]*\).*/\1\/etc\/pki\/tls\/certs\/ca-bundle.crt/' | \
sed 's/^[[:space:]#]*\(TLS_REQCERT[[:space:]][[:space:]]*\).*/\1demand/' \
> .ldap.conf
mv -f .ldap.conf ldap.conf
cd

authconfig --enablesssd --enablesssdauth --enablecachecreds --enableldap --enableldapauth --enablemkhomedir --ldapserver=ldap://ldap.codingcafe.org --ldapbasedn=dc=codingcafe,dc=org --enablelocauthorize --enableldaptls --update

# ================================================================
# Enable Services
# ================================================================

systemctl enable sssd

# ================================================================
# Personalize
# ================================================================

git config --global user.name 'Tongliang Liao'
git config --global user.email 'xkszltl@gmail.com'
git config --global push.default matching
git config --global core.editor 'vim'

# ================================================================
# Compile LLVM
# ================================================================

cd /tmp
git clone https://github.com/llvm-mirror/llvm.git LLVM
cd LLVM
git checkout release_40
cd tools
git clone https://github.com/llvm-mirror/polly.git &
git clone https://github.com/llvm-mirror/lldb.git &
git clone https://github.com/llvm-mirror/lld.git &
git clone https://github.com/llvm-mirror/clang.git
cd clang
git checkout release_40
cd tools
git clone https://github.com/llvm-mirror/clang-tools-extra.git extra
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
git clone https://github.com/llvm-mirror/compiler-rt.git &
git clone https://github.com/llvm-mirror/libunwind.git &
git clone https://github.com/llvm-mirror/libcxx.git &
git clone https://github.com/llvm-mirror/libcxxabi.git &
git clone https://github.com/llvm-mirror/openmp.git &
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
mkdir -p build/Release
cd build/Release

# ----------------------------------------------------------------

cmake3 -DCMAKE_BUILD_TYPE=Release -DCLANG_DEFAULT_CXX_STDLIB=libc++ -DLLVM_CCACHE_BUILD=ON -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON -DLLVM_ENABLE_LIBCXX=ON -DLIBCLANG_BUILD_STATIC=ON -DLIBCXX_CONFIGURE_IDE=ON -DLIBOMP_OMPT_SUPPORT=ON -DLIBOMP_STATS=OFF -DLIBOMP_TSAN_SUPPORT=ON -DLIBOMP_USE_HWLOC=ON -DLIBOMP_USE_STDCPPLIB=ON -DLIBUNWIND_ENABLE_CROSS_UNWINDING=ON -DLLDB_DISABLE_PYTHON=ON -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_ENABLE_CXX1Y=ON -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_FFI=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_INSTALL_UTILS=ON -DLLVM_LINK_LLVM_DYLIB=OFF -DLLVM_OPTIMIZED_TABLEGEN=ON -DPOLLY_ENABLE_GPGPU_CODEGEN=ON ../..
time VERBOSE=1 make -j`nproc --all` install
rm -rf *

# ----------------------------------------------------------------

echo /usr/local/lib > /etc/ld.so.conf.d/libc++-x86_64.conf
ldconfig

# ----------------------------------------------------------------

CC='clang -fPIC -fuse-ld=lld' CXX='clang++ -stdlib=libc++ -lc++abi -fPIC -fuse-ld=lld' LD='lld' cmake3 -DCMAKE_BUILD_TYPE=Release -DCLANG_DEFAULT_CXX_STDLIB=libc++ -DENABLE_X86_RELAX_RELOCATIONS=ON -DLLVM_CCACHE_BUILD=ON -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON -DLLVM_ENABLE_LIBCXX=ON -DLIBCLANG_BUILD_STATIC=ON -DLIBCXX_CONFIGURE_IDE=ON -DLIBOMP_OMPT_SUPPORT=ON -DLIBOMP_STATS=OFF -DLIBOMP_TSAN_SUPPORT=ON -DLIBOMP_USE_HWLOC=ON -DLIBOMP_USE_STDCPPLIB=ON -DLIBUNWIND_ENABLE_CROSS_UNWINDING=ON -DLLDB_DISABLE_PYTHON=ON -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_ENABLE_CXX1Y=ON -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_FFI=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_INSTALL_UTILS=ON -DLLVM_LINK_LLVM_DYLIB=OFF -DLLVM_OPTIMIZED_TABLEGEN=ON -DPOLLY_ENABLE_GPGPU_CODEGEN=ON ../..
time VERBOSE=1 make -j`nproc --all` install

# ----------------------------------------------------------------

ldconfig
cd /tmp
rm -rf LLVM

# ================================================================
# Compile Boost
# ================================================================

cd /tmp
axel -an 20 -o boost.tar.bz2 https://downloads.sourceforge.net/project/boost/boost/1.63.0/boost_1_63_0.tar.bz2
tar -xvf boost.tar.bz2
cd boost*/
# ./bootstrap.sh --with-icu --with-toolset=clang
./bootstrap.sh --with-icu
# LD=lld ./b2 cxxflags="-std=c++1z -stdlib=libc++ -fuse-ld=lld" linkflags="-stdlib=libc++" -aj`nproc --all` install
./b2 -aj`nproc --all` install

# ----------------------------------------------------------------

ldconfig
cd /tmp
rm -rf boost*

# ================================================================
# Cleanup
# ================================================================

yum autoremove -y
yum clean all
cd
truncate -s 0 .bash_history
