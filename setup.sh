#!/bin/bash

# ================================================================
# YUM Configuration
# ================================================================

yum-config-manager --setopt=tsflags= --save
yum update -y --skip-broken
yum update -y
yum install -y curl
rpm -i "http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/`curl -s http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/ | sed -n 's/.*\(cuda-repo-rhel7-.*\.x86_64\.rpm\).*/\1/p' | sort | tail -n 1`"
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.rpm.sh | bash
yum install -y epel-release
# yum install -y centos-release-scl{,-rh}
yum update -y --skip-broken
yum update -y
yum-config-manager --enable extras centosplus {base,epel}-debuginfo
# yum-config-manager --enable centos-sclo-{sclo,rh}-debuginfo
yum update -y --skip-broken
yum update -y

yum install -y yum-{axelget,plugin-priorities}

# ================================================================
# Install Packages
# ================================================================

yum remove -y compat-qpid-cpp-client{,-*}
yum install -y qpid-cpp-client{,-*}

yum install -y {gcc,distcc,ccache}{,-*}
yum install -y --skip-broken perl{,-*}
yum install -y --skip-broken {python{,34},anaconda}{,-*}
yum install -y --skip-broken ruby{,-*}
yum install -y java-1.8.0-openjdk{,-*}
yum install -y texlive{,-*}
yum install -y {gdb,valgrind,perf,{l,s}trace}{,-*}
yum install -y {make,cmake{,3},autoconf,libtool,ant,maven}{,-*}
yum install -y {git,subversion,mercurial}{,-*}
yum install -y doxygen{,-*}

yum install -y vim{,-*}
yum install -y dos2unix{,-*}

yum install -y {bash,fish,zsh,mosh,tmux}{,-*}
yum install -y {telnet,tftp,rsh}{,-debuginfo}
yum install -y {htop,glances}{,-*}
yum install -y {wget,axel,curl}{,-*}
yum install -y man{,-*}
yum install -y {f,tc,dhc,libo,io}ping{,-*}
yum install -y hping3{,-*}
yum install -y {traceroute,rsync,tcpdump}{,-*}
yum install -y net-snmp{,-*}
yum install -y GeoIP{,-*}
yum install -y dstat{,-*}
yum install -y lm_sensors{,-*}
yum install -y {{e2fs,btrfs-,xfs,ntfs}progs,xfsdump,nfs-utils}{,-*}
yum install -y dd{,_}rescue{,-*}
yum install -y docker{,-*}

yum install -y ncurses{,-*}
yum install -y hwloc{,-*}
yum install -y icu{,-*}
yum install -y {gmp,mpfr,libmpc}{,-*}
yum install -y lib{jpeg-turbo,tiff,png}{,-*}
yum install -y {zlib,libzip,{,p}xz,snappy}{,-*}
yum install -y lib{telnet,ssh{,2},curl,aio,ffi,edit,icu}{,-*}
yum install -y boost{,-*}
yum install -y open{blas,cv,ssl,ssh,ldap}{,-*}
yum install -y {gflags,glog,protobuf}{,-*}
yum install -y ImageMagick{,-*}
yum install -y --skip-broken qt5{,-*}
yum install -y cuda

yum install -y {hdf5}{,-*}
yum install -y {leveldb,lmdb}{,-*}
yum install -y {mariadb,postgresql}{,-*}

yum install -y {fio,filebench}{,-*}

yum install -y {nss,sssd}{,-*}

yum install -y gitlab-ci-multi-runner

yum update -y --skip-broken
yum update -y

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
cmake3 -DCMAKE_BUILD_TYPE=Release -DCLANG_DEFAULT_CXX_STDLIB=libc++ -DLLVM_CCACHE_BUILD=ON -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON -DLLVM_ENABLE_LIBCXX=ON -DLIBCLANG_BUILD_STATIC=ON -DLIBCXX_CONFIGURE_IDE=ON -DLIBOMP_OMPT_SUPPORT=ON -DLIBOMP_STATS=OFF -DLIBOMP_TSAN_SUPPORT=ON -DLIBOMP_USE_HWLOC=ON -DLIBOMP_USE_STDCPPLIB=ON -DLIBUNWIND_ENABLE_CROSS_UNWINDING=ON -DLLDB_DISABLE_PYTHON=ON -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_ENABLE_CXX1Y=ON -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_FFI=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_INSTALL_UTILS=ON -DLLVM_LINK_LLVM_DYLIB=OFF -DLLVM_OPTIMIZED_TABLEGEN=ON -DPOLLY_ENABLE_GPGPU_CODEGEN=ON ../..
time VERBOSE=1 make -j`nproc --all` install
rm -rf *
echo /usr/local/lib > /etc/ld.so.conf.d/libc++-x86_64.conf
ldconfig
CC='clang -fPIC -fuse-ld=lld' CXX='clang++ -stdlib=libc++ -lc++abi -fPIC -fuse-ld=lld' LD='lld' cmake3 -DCMAKE_BUILD_TYPE=Release -DCLANG_DEFAULT_CXX_STDLIB=libc++ -DENABLE_X86_RELAX_RELOCATIONS=ON -DLLVM_CCACHE_BUILD=ON -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON -DLLVM_ENABLE_LIBCXX=ON -DLIBCLANG_BUILD_STATIC=ON -DLIBCXX_CONFIGURE_IDE=ON -DLIBOMP_OMPT_SUPPORT=ON -DLIBOMP_STATS=OFF -DLIBOMP_TSAN_SUPPORT=ON -DLIBOMP_USE_HWLOC=ON -DLIBOMP_USE_STDCPPLIB=ON -DLIBUNWIND_ENABLE_CROSS_UNWINDING=ON -DLLDB_DISABLE_PYTHON=ON -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_ENABLE_CXX1Y=ON -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_FFI=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_INSTALL_UTILS=ON -DLLVM_LINK_LLVM_DYLIB=OFF -DLLVM_OPTIMIZED_TABLEGEN=ON -DPOLLY_ENABLE_GPGPU_CODEGEN=ON ../..
time VERBOSE=1 make -j`nproc --all` install
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
cd /tmp
rm -rf boost*

# ================================================================
# Cleanup
# ================================================================

yum autoremove -y
yum clean all
cd
truncate -s 0 .bash_history
