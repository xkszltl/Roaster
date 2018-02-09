#!/bin/bash

# ================================================================
# Repo Cache
# ================================================================

set -e
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# ----------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------

export DRY=false
export REPO_UPDATE=false
export MAX_ATTEMPT=3
export USE_PROXY=false

# ----------------------------------------------------------------
# Preparation
# ----------------------------------------------------------------

export DRY_RSYNC=$($DRY && echo --dry-run)
export DRY_WGET=$($DRY && echo --spider)

export REPOSYNC='reposync
    --cachedir=$(mktemp -d)
    --download-metadata
    --downloadcomps
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
    '"$($REPO_UPDATE && echo --keep-all-metadata)"'
    --pretty
    --workers $(nproc)
    '"$($REPO_UPDATE && echo --update)"'
    $(pwd)
'

export ROUTE='10.0.0.$([ $(expr $RANDOM % 15) -lt 10 ] && echo 12 || echo 11)'

export TASKS=''

mkdir -p /var/www/repos
cd $_

# ----------------------------------------------------------------
# CTAN Repository Mirroring
# ----------------------------------------------------------------

if false; then :
elif ping -nfc 10 mirrors.tuna.tsinghua.edu.cn -I 10.0.0.11; then
    $DRY || rsync $DRY_RSYNC -avPz --delete --address 10.0.0.11 rsync://mirrors.tuna.tsinghua.edu.cn/CTAN/ CTAN &
elif ping -nfc 10 rsync.mirrors.ustc.edu.cn -I 10.0.0.12; then
    $DRY || rsync $DRY_RSYNC -avPz --delete --address 10.0.0.12 rsync://rsync.mirrors.ustc.edu.cn/CTAN/ CTAN &
elif ping -nfc 10 mirrors.tuna.tsinghua.edu.cn -I 10.0.0.12; then
    $DRY || rsync $DRY_RSYNC -avPz --delete --address 10.0.0.12 rsync://mirrors.tuna.tsinghua.edu.cn/CTAN/ CTAN &
elif ping -nfc 10 rsync.mirrors.ustc.edu.cn -I 10.0.0.11; then
    $DRY || rsync $DRY_RSYNC -avPz --delete --address 10.0.0.11 rsync://rsync.mirrors.ustc.edu.cn/CTAN/ CTAN &
else
    echo "No mirror to try for CTAN"
    exit 1
fi

# ----------------------------------------------------------------
# Intel Repository Mirroring
# ----------------------------------------------------------------

parallel -j0 --line-buffer --bar 'bash -c '"'"'
    export INTEL_URL="http://registrationcenter-download.intel.com/akdlm/irc_nas/tec"

    mkdir -p intel
    cd $_

    $DRY || wget $DRY_WGET -cq --bind-address='$ROUTE' $INTEL_URL/{}
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

# ----------------------------------------------------------------
# NVIDIA Repository Mirroring
# ----------------------------------------------------------------

parallel -j0 --line-buffer --bar 'bash -c '"'"'
    export CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn"
    export lhs=$(sed "s/=.*//" <<< "{}")
    export rhs=$(sed "s/.*=//" <<< "{}")

    mkdir -p nvidia/cudnn/$lhs
    cd $_

    $DRY || wget $DRY_WGET -cq --bind-address='$ROUTE' $CUDNN_URL/$(basename $lhs)/cudnn-$(printf $rhs x64-$(basename $lhs | cut -f1 -d.))
'"'" :::    \
    v7.0.{4,5}=9.{0,1,2,3,4,5,6,7,8,9}-{{linux,osx}-%s.tgz,windows10-%s.zip}    \
&

# ----------------------------------------------------------------
# NVIDIA Repository Mirroring
# ----------------------------------------------------------------

yum makecache fast -y || true
rm -rf $(find . -name .repodata -type d)

# ----------------------------------------------------------------
# Proxy
# ----------------------------------------------------------------

if $USE_PROXY; then
    export HTTP_PROXY=proxy.codingcafe.org:8118
    [ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
    [ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
    [ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY
fi

# ----------------------------------------------------------------
# CentOS Repository Mirroring Task
# ----------------------------------------------------------------

for i in base updates extras centosplus; do
for j in =$(uname -i) -source=Source $([ $i = base ] && echo -debuginfo=debug/$(uname -i)); do
    export lhs=$(sed 's/=.*//' <<< $j)
    export rhs=$(sed 's/.*=//' <<< $j)
    export REPO_TASKS="$REPO_TASKS
    {
        \"repo\": \"$i$lhs\",
        \"path\": \"centos/7/$i/$rhs\"
    },"
done
done

# ----------------------------------------------------------------

for i in {=,-debuginfo=debug/}$(uname -i) -source=SRPMS; do
    export lhs=$(sed 's/=.*//' <<< $i)
    export rhs=$(sed 's/.*=//' <<< $i)
    export REPO_TASKS="$REPO_TASKS
    {
        \"repo\": \"epel$lhs\",
        \"path\": \"epel/7/$rhs\"
    },"
done

# ----------------------------------------------------------------
# SCL Repository Mirroring Task
# ----------------------------------------------------------------

for i in sclo rh; do
for j in =$(uname -i)/$i -testing=$(uname -i)/$i/testing -source=Source/$i -debuginfo=$(uname -i)/$i/debuginfo; do
    export lhs=$(sed 's/=.*//' <<< $j)
    export rhs=$(sed 's/.*=//' <<< $j)
    export REPO_TASKS="$REPO_TASKS
    {
        \"repo\": \"centos-sclo-$i$lhs\",
        \"path\": \"centos/7/sclo/$rhs\"
    },"
done
done

# ----------------------------------------------------------------
# ELRepo Repository Mirroring Task
# ----------------------------------------------------------------

for i in elrepo{,-testing,-kernel,-extras}; do
    export REPO_TASKS="$REPO_TASKS
    {
        \"repo\": \"$i\",
        \"path\": \"$(sed 's/-/\//' <<< $i)/el7\"
    },"
done

# ----------------------------------------------------------------
# CUDA Repository Mirroring Task
# ----------------------------------------------------------------

(
    set -e

    mkdir -p cuda/rhel7/$(uname -i)
    cd $_
    $DRY || wget $DRY_WGET -cq https://developer.download.nvidia.com/compute/cuda/repos/rhel7/$(uname -i)/7fa2af80.pub
    $DRY || rpm --import 7fa2af80.pub
)

export REPO_TASKS="$REPO_TASKS
{
    \"repo\": \"cuda\",
    \"path\": \"cuda/rhel7/$(uname -i)\"
},"

# ----------------------------------------------------------------
# Docker Repository Mirroring Task
# ----------------------------------------------------------------

(
    set -e

    mkdir -p docker/linux/centos
    cd $_
    $DRY || wget $DRY_WGET -cq https://download.docker.com/linux/centos/gpg
    $DRY || rpm --import gpg
)

for i in stable edge test; do :
for j in {=,-debuginfo=debug-}$(uname -i) -source=source; do
    export lhs=$(sed 's/=.*//' <<< $j)
    export rhs=$(sed 's/.*=//' <<< $j)
    export REPO_TASKS="$REPO_TASKS
    {
        \"repo\": \"docker-ce-$i$lhs\",
        \"path\": \"docker/linux/centos/7/$rhs/$i\"
    },"
done
done

# ----------------------------------------------------------------
# GitLab-CE Repository Mirroring Task
# ----------------------------------------------------------------

for i in =$(uname -i) -source=SRPMS; do
    export lhs=$(sed 's/=.*//' <<< $i)
    export rhs=$(sed 's/.*=//' <<< $i)
    export REPO_TASKS="$REPO_TASKS
    {
        \"repo\": \"gitlab_gitlab-ce$lhs\",
        \"path\": \"gitlab/gitlab-ce/el/7/$rhs\",
        \"sync_args\": \"--newest-only\"
    },"
done

# ----------------------------------------------------------------
# GitLab CI Runner Repository Mirroring Task
# ----------------------------------------------------------------

for j in =$(uname -i) -source=SRPMS; do
    export lhs=$(sed 's/=.*//' <<< $i)
    export rhs=$(sed 's/.*=//' <<< $i)
    export REPO_TASKS="$REPO_TASKS
    {
        \"repo\": \"runner_gitlab-ci-multi-runner$lhs\",
        \"path\": \"gitlab/gitlab-ci-multi-runner/el/7/$rhs\",
        \"sync_args\": \"--newest-only\"
    },"
done

# ----------------------------------------------------------------
# Task Execution
# ----------------------------------------------------------------

export REPO_TASKS=$(sed 's/,[[:space:]]*\(\]\)/\1/g' <<< "
{
    \"repo_tasks\": [ $REPO_TASKS ]
}")

parallel -j0 --line-buffer --bar 'bash -c '"'"'
    export JSON_OBJ=$(jq ".repo_tasks | .[{}]" <<< "$REPO_TASKS")
    echo "Execute task $JSON_OBJ"

    export repo=$(jq -r ".repo" <<< "$JSON_OBJ")
    export path=$(jq -r ".path" <<< "$JSON_OBJ")
    jq -e ".sync_args" <<< "$JSON_OBJ" > /dev/null && export sync_args=$(jq -r ".sync_args" <<< "$JSON_OBJ")

    mkdir -p $path
    cd $_
    for attempt in $(seq $MAX_ATTEMPT); do
        eval $REPOSYNC $repo $sync_args && break
        echo "Retry \"$repo\""
    done
    eval $CREATEREPO
'"'" :::    \
    $(seq 0 $(expr $(jq '.repo_tasks | length' <<< "$REPO_TASKS") - 1)) \
&

# ----------------------------------------------------------------

wait
trap - SIGTERM SIGINT EXIT
