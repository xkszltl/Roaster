#!/bin/bash

# ================================================================
# Repo Cache
# ================================================================

set -e
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

date

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
    --plugins
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
# CTAN/GNU Repository Mirroring
# ----------------------------------------------------------------

parallel -j0 --line-buffer --bar 'bash -c '"'"'
    [ "'"$#"'" -eq 0 ] || grep -i {} <<< "'"$@"'" || exit 0
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
    [ "'"$#"'" -eq 0 ] || grep -i intel <<< "'"$@"'" || exit 0
    export INTEL_URL="http://registrationcenter-download.intel.com/akdlm/irc_nas/tec"

    mkdir -p intel
    cd "$_"

    $DRY || wget $DRY_WGET -cq --bind-address='$ROUTE' $INTEL_URL/{}
'"'" :::   \
    16234/l_daal_2020.0.166.tgz     \
    16233/l_ipp_2020.0.166.tgz      \
    16232/l_mkl_2020.0.166.tgz      \
    16120/l_mpi_2019.6.166.tgz      \
    16269/l_tbb_2020.0.166.tgz      \
    16266/m_daal_2020.0.166.dmg     \
    16239/m_ipp_2020.0.166.dmg      \
    16240/m_mkl_2020.0.166.dmg      \
    16270/m_tbb_2020.0.166.dmg      \
    16224/w_daal_2020.0.166.exe     \
    16223/w_ipp_2020.0.166.exe      \
    16222/w_mkl_2020.0.166.exe      \
    16272/w_mpi_p_2019.6.166.exe    \
    16271/w_tbb_2020.0.166.exe      \
&

# ----------------------------------------------------------------
# Makecache
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

for i in base updates extras centosplus dotnet; do
for j in =$(uname -i) -source=Source $([ "_$i" = '_base' ] && echo -debuginfo=debug/$(uname -i)); do
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
        "repo":         "'"centos-sclo-$i$lhs"'",
        "path":         "'"centos/7/sclo/$rhs"'",
        "retries":      '$DEF_RETRIES'
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

for sub_repo in cuda,cuda nvidia-machine-learning,machine-learning; do
for dist in rhel7; do
    name="$(cut -d',' -f1 <<< "$sub_repo,")"
    dir="$(cut -d',' -f2 <<< "$sub_repo,")"
    mkdir -p "nvidia/$dir/$dist/$(uname -i)"
    pushd "$_"
    $DRY || wget $DRY_WGET -cq "https://developer.download.nvidia.com/compute/$dir/repos/$dist/$(uname -i)/7fa2af80.pub"
    $DRY || rpm --import "7fa2af80.pub"
    popd

    export REPO_TASKS=$(jq <<< "$REPO_TASKS" '.repo_tasks[.repo_tasks | length] |= . +
    {
        "repo":         "'"$name"'",
        "path":         "'"nvidia/$dir/$dist/$(uname -i)"'",
        "retries":      10,
        "use_proxy":    "'"false"'",
        "sync_args":    "--delete"
    }')
done
done

for i in libnvidia-container nvidia-{container-runtime,docker}; do
    mkdir -p "nvidia/$i/centos7/$(uname -i)"
    pushd "$_"
    $DRY || wget $DRY_WGET -cq "https://nvidia.github.io/$i/gpgkey"
    $DRY || rpm --import "gpgkey"
    popd

    export REPO_TASKS=$(jq <<< "$REPO_TASKS" '.repo_tasks[.repo_tasks | length] |= . +
    {
        "repo":         "'"$i"'",
        "path":         "'"nvidia/$i/centos7/$(uname -i)"'",
        "retries":      10,
        "use_proxy":    "'"false"'",
        "sync_args":    "--delete"
    }')
done

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
    [ "'"$#"'" -eq 0 ] || grep -i "$repo" <<< "'"$@"'" || exit 0
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
            if [ "$rest" -ge 0 ]; then
                echo -n "Retry \"$repo\". "
                if [ "$rest" -gt 0 ]; then
                    echo "$rest time(s) left."
                elif [ "$use_proxy" ]; then
                    echo "Try once without proxy."
                else
                    echo "Try once with proxy."
                fi
            fi
        fi
    done
    $DRY || eval $CREATEREPO
'"'" :::    \
    $(seq 0 $(expr $(jq <<< "$REPO_TASKS" '.repo_tasks | length') - 1)) \
&

# ----------------------------------------------------------------

wait

date

trap - SIGTERM SIGINT EXIT
