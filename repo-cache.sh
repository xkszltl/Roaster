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
export REPO_GPG=false
export DEF_RETRIES=2
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
    '"$($REPO_GPG && echo --gpgcheck)"'
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

export ROUTE='10.0.0.$([ $(expr $RANDOM % 13) -lt 9 ] && echo 12 || echo 11)'

export REPO_TASKS=$(jq -n '
    {
        "repo_tasks": []
    }')

mkdir -p '/var/www/repos'
cd "$_"

# ----------------------------------------------------------------
# CTAN Repository Mirroring
# ----------------------------------------------------------------

parallel -j0 --line-buffer --bar 'bash -c '"'"'
    if false; then :
    elif ping -nfc 10 mirrors.tuna.tsinghua.edu.cn -I 10.0.0.12; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete --address 10.0.0.12 "rsync://mirrors.tuna.tsinghua.edu.cn/{}/" "{}"
    elif ping -nfc 10 rsync.mirrors.ustc.edu.cn -I 10.0.0.12; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete --address 10.0.0.12 "rsync://rsync.mirrors.ustc.edu.cn/{}/" "{}"
    elif ping -nfc 10 mirrors.tuna.tsinghua.edu.cn -I 10.0.0.11; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete --address 10.0.0.11 "rsync://mirrors.tuna.tsinghua.edu.cn/{}/" "{}"
    elif ping -nfc 10 rsync.mirrors.ustc.edu.cn -I 10.0.0.11; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete --address 10.0.0.11 "rsync://rsync.mirrors.ustc.edu.cn/{}/" "$u"
    else
       echo "No mirror to try for $i"
       exit 1
    fi
'"'" ::: CTAN gnu

# ----------------------------------------------------------------
# Intel Repository Mirroring
# ----------------------------------------------------------------

parallel -j0 --line-buffer --bar 'bash -c '"'"'
    export INTEL_URL="http://registrationcenter-download.intel.com/akdlm/irc_nas/tec"

    mkdir -p intel
    cd "$_"

    $DRY || wget $DRY_WGET -cq --bind-address='$ROUTE' $INTEL_URL/{}
'"'" :::   \
    13007/l_daal_2018.3.222.tgz     \
    13005/l_mkl_2018.3.222.tgz      \
    13006/l_ipp_2018.3.222.tgz      \
    13112/l_tbb_2018.4.222.tgz      \
    13112/l_mpi_2018.3.222.tgz      \
    13109/m_daal_2018.3.185.dmg     \
    13011/m_ipp_2018.3.185.dmg      \
    13012/m_mkl_2018.3.185.dmg      \
    13113/m_tbb_2018.4.185.dmg      \
    13039/w_daal_2018.3.210.exe     \
    13037/w_mkl_2018.3.210.exe      \
    13038/w_ipp_2018.3.210.exe      \
    13111/w_tbb_2018.4.210.exe      \
    13111/w_mpi_p_2018.3.210.exe    \
&

# ----------------------------------------------------------------
# NVIDIA Repository Mirroring
# ----------------------------------------------------------------

parallel -j10 --line-buffer --bar 'bash -c '"'"'
    export CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn"
    export lhs=$(sed "s/@.*//" <<< "{}")
    export rhs=$(sed "s/.*@//" <<< "{}")

    mkdir -p "nvidia/cudnn/$lhs"
    cd "$_"

    '"$DRY"' || wget '"$DRY_WGET"' -cq --bind-address='"$ROUTE"' "$CUDNN_URL/$lhs/cudnn-$(printf "$rhs" "x64-$(cut -d. -f1,2 <<< "$lhs" | sed "s/\.0$//")")"
    [ $(ls | wc -l) -le 0 ] && cd .. && rm -rf "$lhs"
'"'" ::: v7.{1,2}.{0,1,2,3,4,5,6,7,8,9}@9.{0,1,2,3}-{{linux,osx}-%s.tgz,windows10-%s.zip} &

# ----------------------------------------------------------------
# NVIDIA Repository Mirroring
# ----------------------------------------------------------------

yum makecache fast -y || true
rm -rf $(find . -name .repodata -type d)

# ----------------------------------------------------------------
# Proxy
# ----------------------------------------------------------------

if $USE_PROXY; then
    export HTTP_PROXY="proxy.codingcafe.org:8118"
    [ "$HTTP_PROXY"  ] && export HTTPS_PROXY="$HTTP_PROXY"
    [ "$HTTP_PROXY"  ] && export http_proxy="$HTTP_PROXY"
    [ "$HTTPS_PROXY" ] && export https_proxy="$HTTPS_PROXY"
fi

# ----------------------------------------------------------------
# CentOS Repository Mirroring Task
# ----------------------------------------------------------------

for i in base updates extras centosplus; do
for j in =$(uname -i) -source=Source $([ $i = base ] && echo -debuginfo=debug/$(uname -i)); do
    export lhs=$(sed 's/=.*//' <<< $j)
    export rhs=$(sed 's/.*=//' <<< $j)
    export REPO_TASKS=$(jq <<< "$REPO_TASKS" '.repo_tasks[.repo_tasks | length] |= . +
    {
        "repo":         "'"$i$lhs"'",
        "path":         "'"centos/7/$i/$rhs"'",
        "retries":      '$DEF_RETRIES',
        "sync_args":    "--delete '"$([ $i$lhs = base-debuginfo ] && echo --newest-only)"'"
    }')
done
done

# ----------------------------------------------------------------

for i in {=,-debuginfo=debug/}$(uname -i) -source=SRPMS; do
    export lhs=$(sed 's/=.*//' <<< $i)
    export rhs=$(sed 's/.*=//' <<< $i)
    export REPO_TASKS=$(jq <<< "$REPO_TASKS" '.repo_tasks[.repo_tasks | length] |= . +
    {
        "repo":         "'"epel$lhs"'",
        "path":         "'"epel/7/$rhs"'",
        "retries":      '$DEF_RETRIES',
        "sync_args":    "--delete '"$([ epel$lhs = epel-debuginfo ] && echo --newest-only)"'"
    }')
done

# ----------------------------------------------------------------
# SCL Repository Mirroring Task
# ----------------------------------------------------------------

for i in sclo rh; do
for j in =$(uname -i)/$i -testing=$(uname -i)/$i/testing -source=Source/$i -debuginfo=$(uname -i)/$i/debuginfo; do
    export lhs=$(sed 's/=.*//' <<< $j)
    export rhs=$(sed 's/.*=//' <<< $j)
    export REPO_TASKS=$(jq <<< "$REPO_TASKS" '.repo_tasks[.repo_tasks | length] |= . +
    {
        "repo":     "'"centos-sclo-$i$lhs"'",
        "path":     "'"centos/7/sclo/$rhs"'",
        "retries":  '$DEF_RETRIES'
    }')
done
done

# ----------------------------------------------------------------
# ELRepo Repository Mirroring Task
# ----------------------------------------------------------------

for i in elrepo{,-testing,-kernel,-extras}; do
    export REPO_TASKS=$(jq <<< "$REPO_TASKS" '.repo_tasks[.repo_tasks | length] |= . +
    {
        "repo":     "'"$i"'",
        "path":     "'"$(sed 's/-/\//' <<< $i)/el7"'",
        "retries":  '$DEF_RETRIES'
    }')
done

# ----------------------------------------------------------------
# CUDA Repository Mirroring Task
# ----------------------------------------------------------------

(
    set -e

    mkdir -p "cuda/rhel7/$(uname -i)"
    cd "$_"
    $DRY || wget $DRY_WGET -cq https://developer.download.nvidia.com/compute/cuda/repos/rhel7/$(uname -i)/7fa2af80.pub
    $DRY || rpm --import 7fa2af80.pub
)

export REPO_TASKS=$(jq <<< "$REPO_TASKS" '.repo_tasks[.repo_tasks | length] |= . +
{
    "repo":         "'"cuda"'",
    "path":         "'"cuda/rhel7/$(uname -i)"'",
    "retries":      10,
    "use_proxy":    "'"true"'"
}')

# ----------------------------------------------------------------
# Docker Repository Mirroring Task
# ----------------------------------------------------------------

(
    set -e

    mkdir -p 'docker/linux/centos'
    cd "$_"
    $DRY || wget $DRY_WGET -cq https://download.docker.com/linux/centos/gpg
    $DRY || rpm --import gpg
)

for i in stable edge test; do :
for j in {=,-debuginfo=debug-}$(uname -i) -source=source; do
    export lhs=$(sed 's/=.*//' <<< $j)
    export rhs=$(sed 's/.*=//' <<< $j)
    export REPO_TASKS=$(jq <<< "$REPO_TASKS" '.repo_tasks[.repo_tasks | length] |= . +
    {
        "repo":     "'"docker-ce-$i$lhs"'",
        "path":     "'"docker/linux/centos/7/$rhs/$i"'",
        "retries":  10
    }')
done
done

# ----------------------------------------------------------------
# GitLab-CE Repository Mirroring Task
# ----------------------------------------------------------------

for i in =$(uname -i) -source=SRPMS; do
    export lhs=$(sed 's/=.*//' <<< $i)
    export rhs=$(sed 's/.*=//' <<< $i)
    export REPO_TASKS=$(jq <<< "$REPO_TASKS" '.repo_tasks[.repo_tasks | length] |= . +
    {
        "repo":         "'"gitlab_gitlab-ce$lhs"'",
        "path":         "'"gitlab/gitlab-ce/el/7/$rhs"'",
        "retries":      10,
        "sync_args":    "--newest-only"
    }')
done

# ----------------------------------------------------------------
# GitLab CI Runner Repository Mirroring Task
# ----------------------------------------------------------------

for i in =$(uname -i) -source=SRPMS; do
    export lhs=$(sed 's/=.*//' <<< $i)
    export rhs=$(sed 's/.*=//' <<< $i)
    export REPO_TASKS=$(jq <<< "$REPO_TASKS" '.repo_tasks[.repo_tasks | length] |= . +
    {
        "repo":         "'"runner_gitlab-runner$lhs"'",
        "path":         "'"gitlab/gitlab-runner/el/7/$rhs"'",
        "retries":      10,
        "sync_args":    "--newest-only"
    }')
done

# ----------------------------------------------------------------
# Task Execution
# ----------------------------------------------------------------

parallel -j0 --line-buffer --bar 'bash -c '"'"'
    export JSON_OBJ=$(jq <<< "$REPO_TASKS" ".repo_tasks | .[{}]")
    printf "Execute task\n%s\n" "$JSON_OBJ"

    export repo=$(jq -r ".repo" <<< "$JSON_OBJ")
    export path=$(jq -r ".path" <<< "$JSON_OBJ")
    jq -e ".sync_args" <<< "$JSON_OBJ" > /dev/null && export sync_args=$(jq -r ".sync_args" <<< "$JSON_OBJ")
    export retries=1
    jq -e ".retries" <<< "$JSON_OBJ" > /dev/null && export retries=$(jq -r ".retries" <<< "$JSON_OBJ")
    export use_proxy="'"$USE_PROXY"'"
    jq -e ".use_proxy" <<< "$JSON_OBJ" > /dev/null && export use_proxy=$(jq -r ".use_proxy" <<< "$JSON_OBJ")

    mkdir -p "$path"
    cd "$_"
    for rest in $(seq "$retries" -1 -1); do
        if [ "$rest" -ge 0 ] && "$use_proxy" || [ "$rest" -ne 0 ] && ! "$use_proxy" ; then
            export HTTP_PROXY="proxy.codingcafe.org:8118"
            [ "$HTTP_PROXY"  ] && export HTTPS_PROXY="$HTTP_PROXY"
            [ "$HTTP_PROXY"  ] && export http_proxy="$HTTP_PROXY"
            [ "$HTTPS_PROXY" ] && export https_proxy="$HTTPS_PROXY"
        else
            unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
        fi
        if ! "$DRY"; then
            eval $REPOSYNC $repo $sync_args && break
            echo -n "Retry \"$repo\". "
            if [ "$rest" -gt 0 ]; then
                echo "$rest time(s) left."
            elif [ "$use_proxy" ]; then
                echo "Try once without proxy."
            else
                echo "Try once with proxy."
            fi
        fi
    done
    $DRY || eval $CREATEREPO
'"'" :::    \
    $(seq 0 $(expr $(jq <<< "$REPO_TASKS" '.repo_tasks | length') - 1)) \
&

# ----------------------------------------------------------------

wait
trap - SIGTERM SIGINT EXIT
