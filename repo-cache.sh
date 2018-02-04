#!/bin/bash

# ================================================================
# Repo Cache
# ================================================================

set -e
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# ----------------------------------------------------------------

export REPOSYNC='reposync
    --cachedir=$(mktemp -d)
    --download-metadata
    --downloadcomps
    --gpgcheck
    --norepopath
    --source
    -r
'

export CREATEREPO='createrepo_c
    --cachedir=.cache
    --checksum=sha512
    --compress-type=xz
    --database
    $([ -f comps.xml ] && echo --groupfile=comps.xml)
    --pretty
    --workers $(nproc)
    $(pwd)
'

export ROUTE='10.0.0.$([ $(expr $RANDOM % 15) -lt 10 ] && echo 12 || echo 11)'

export MAX_ATTEMPT=4

mkdir -p /var/www/repos
cd $_

# ----------------------------------------------------------------

if false; then :
elif ping -nfc 10 mirrors.tuna.tsinghua.edu.cn -I 10.0.0.11; then
    rsync -avPz --delete --address 10.0.0.11 rsync://mirrors.tuna.tsinghua.edu.cn/CTAN/ CTAN &
elif ping -nfc 10 rsync.mirrors.ustc.edu.cn -I 10.0.0.12; then
    rsync -avPz --delete --address 10.0.0.12 rsync://rsync.mirrors.ustc.edu.cn/CTAN/ CTAN &
elif ping -nfc 10 mirrors.tuna.tsinghua.edu.cn -I 10.0.0.12; then
    rsync -avPz --delete --address 10.0.0.12 rsync://mirrors.tuna.tsinghua.edu.cn/CTAN/ CTAN &
elif ping -nfc 10 rsync.mirrors.ustc.edu.cn -I 10.0.0.11; then
    rsync -avPz --delete --address 10.0.0.11 rsync://rsync.mirrors.ustc.edu.cn/CTAN/ CTAN &
else
    echo "No mirror to try for CTAN"
    exit 1
fi

# ----------------------------------------------------------------

(
    set -e
    mkdir -p intel
    cd $_

    export INTEL_URL="http://registrationcenter-download.intel.com/akdlm/irc_nas/tec"

    parallel --line-buffer --bar 'bash -c '"'"'
        wget -cq --bind-address='$ROUTE' $INTEL_URL/{}
    '"'" :::   \
        12414/l_daal_2018.1.163.tgz     \
        12414/l_mkl_2018.1.163.tgz      \
        12414/l_ipp_2018.1.163.tgz      \
        12414/l_tbb_2018.1.163.tgz      \
        12414/l_mpi_2018.1.163.tgz      \
        12409/m_daal_2018.1.126.dmg     \
        12334/m_ipp_2018.1.126.dmg      \
        12335/m_mkl_2018.1.126.dmg      \
        12415/m_tbb_2018.1.126.dmg      \
        12396/w_daal_2018.1.156.exe     \
        12394/w_mkl_2018.1.156.exe      \
        12395/w_ipp_2018.1.156.exe      \
        12418/w_tbb_2018.1.156.exe      \
        12443/w_mpi_p_2018.1.156.exe    \
    &
)

# ----------------------------------------------------------------

(
    set -e
    mkdir -p nvidia/cudnn
    cd $_

    for i in v7.0.{4,5}; do
        mkdir -p $i
        pushd $_
        for j in 9.{0,1,2,3,4,5,6,7,8,9}-{{linux,osx}-%s.tgz,windows10-%s.zip}; do
            wget -cq --bind-address=$(eval 'echo '$ROUTE) https://developer.download.nvidia.com/compute/redist/cudnn/$(basename $(pwd))/cudnn-$(printf $j x64-$(basename $(pwd) | sed 's/\..*//')) &
        done
        popd
    done
)

# ----------------------------------------------------------------

export HTTP_PROXY=proxy.codingcafe.org:8118
[ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
[ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
[ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY

# ----------------------------------------------------------------

yum makecache fast -y || true
rm -rf $(find . -name .repodata -type d)

# ----------------------------------------------------------------

for i in base updates extras centosplus; do :
for j in =$(uname -i) -source=Source $([ $i = base ] && echo -debuginfo=debug/$(uname -i)); do :
(
    set -e
    mkdir -p centos/7/$i/$(sed 's/.*=//' <<< $j)
    cd $_
    for attempt in $(seq $MAX_ATTEMPT); do
        eval $REPOSYNC $i$(sed 's/=.*//' <<< $j) && break
        echo "Retry \"$i$(sed 's/=.*//' <<< $j)\""
    done
    eval $CREATEREPO
) &
done
done

# ----------------------------------------------------------------

for i in {=,-debuginfo=debug/}$(uname -i) -source=SRPMS; do :
(
    set -e
    mkdir -p epel/7/$(sed 's/.*=//' <<< $i)
    cd $_
    for attempt in $(seq $MAX_ATTEMPT); do
        eval $REPOSYNC epel$(sed 's/=.*//' <<< $i) && break
        echo "Retry \"epel$(sed 's/=.*//' <<< $i)\""
    done
    eval $CREATEREPO
) &
done

# ----------------------------------------------------------------

for i in sclo rh; do :
for j in =$(uname -i)/$i -testing=$(uname -i)/$i/testing -source=Source/$i -debuginfo=$(uname -i)/$i/debuginfo; do :
(
    set -e
    mkdir -p centos/7/sclo/$(sed 's/.*=//' <<< $j)
    cd $_
    for attempt in $(seq $MAX_ATTEMPT); do
        eval $REPOSYNC centos-sclo-$i$(sed 's/=.*//' <<< $j) && break
        echo "Retry \"centos-sclo-$i$(sed 's/=.*//' <<< $j)\""
    done
    eval $CREATEREPO
) &
done
done

# ----------------------------------------------------------------

for i in elrepo{,-testing,-kernel,-extras}; do :
(
    set -e
    mkdir -p $(sed 's/-/\//' <<< $i)/el7
    cd $_
    for attempt in $(seq $MAX_ATTEMPT); do
        eval $REPOSYNC $i && break
        echo "Retry \"$i\""
    done
    eval $CREATEREPO
) &
done

# ----------------------------------------------------------------

(
    set -e
    mkdir -p cuda/rhel7/$(uname -i)
    cd $_
    rpm --import https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/7fa2af80.pub
    for attempt in $(seq $MAX_ATTEMPT); do
        eval $REPOSYNC cuda && break
        echo "Retry \"cuda\""
    done
    eval $CREATEREPO
) &

# ----------------------------------------------------------------

(
    set -e
    mkdir -p docker/linux/centos
    cd $_
    wget -cq https://download.docker.com/linux/centos/gpg
    rpm --import gpg
)

for i in {=,-debuginfo=debug-}$(uname -i) -source=source; do :
for j in stable edge test; do :
(
    set -e
    mkdir -p docker/linux/centos/7/$(sed 's/.*=//' <<< $i)/$j
    cd $_
    for attempt in $(seq $MAX_ATTEMPT); do
        eval $REPOSYNC docker-ce-$j$(sed 's/=.*//' <<< $i) && break
        echo "Retry \"docker-ce-$j$(sed 's/=.*//' <<< $i)\""
    done
    eval $CREATEREPO
) &
done
done

# ----------------------------------------------------------------

for i in gitlab=gitlab-ce runner=gitlab-ci-multi-runner; do :
for j in =$(uname -i) -source=SRPMS; do :
(
    set -e
    mkdir -p gitlab/$(sed 's/.*=//' <<< $i)/el/7/$(sed 's/.*=//' <<< $j)
    cd $_
    for attempt in $(seq $MAX_ATTEMPT); do
        eval $REPOSYNC $(sed 's/=.*//' <<< $i)_$(sed 's/.*=//' <<< $i)$(sed 's/=.*//' <<< $j) $([ $(sed 's/=.*//' <<< $i) = gitlab ] && echo '--newest-only') && break
        echo "Retry \"$(sed 's/=.*//' <<< $i)_$(sed 's/.*=//' <<< $i)$(sed 's/=.*//' <<< $j)\""
    done
    eval $CREATEREPO
) &
done
done

# ----------------------------------------------------------------

wait
trap - SIGTERM SIGINT EXIT
