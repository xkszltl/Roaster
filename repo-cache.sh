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

export CLEAN_CACHE='dnf clean dbcache expire-cache metadata --repo'

# Known issue:
#   - Nvidia CDN in China has terrible availability.
#     It is very likely to get "Failed to connect to origin, please retry" in HTTP 200.
#     Disable plugin (yum-axelget) and use only one connection may help.
export REPOSYNC='dnf reposync
    --download-metadata
    '"$($REPO_GPG || echo --nogpgcheck)"'
    '"$(false && --norepopath)"'
    --repoid
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

export ROUTE='10.0.0.$([ $(expr $RANDOM % "$(expr 20 + 10 - 2)") -lt "$(expr 20 - 1)" ] && echo 11 || echo 12)'

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
# Intel Legacy Repository Mirroring
# ----------------------------------------------------------------

parallel -j0 --line-buffer --bar 'bash -c '"'"'
    [ "'"$#"'" -eq 0 ] || grep -i intel <<< "'"$@"'" || exit 0
    export INTEL_URL="http://registrationcenter-download.intel.com/akdlm/irc_nas/tec"

    mkdir -p intel
    cd "$_"

    $DRY || wget $DRY_WGET -cqt 10 --bind-address='$ROUTE' $INTEL_URL/{}
'"'" :::   \
    17130/l_daal_2020.3.304.tgz     \
    17154/l_ipp_2020.3.304.tgz      \
    16917/l_mkl_2020.4.304.tgz      \
    17263/l_mpi_2019.9.304.tgz      \
    17270/l_tbb_2020.3.304.tgz      \
    17134/m_daal_2020.3.301.dmg     \
    17165/m_ipp_2020.3.301.dmg      \
    17172/m_mkl_2020.4.301.dmg      \
    17272/m_tbb_2020.3.301.dmg      \
    17133/w_daal_2020.3.311.exe     \
    17166/w_ipp_2020.3.311.exe      \
    17173/w_mkl_2020.4.311.exe      \
    17265/w_mpi_p_2019.9.311.exe    \
    17271/w_tbb_2020.3.311.exe      \
&

# ----------------------------------------------------------------
# Makecache
# ----------------------------------------------------------------

# dnf makecache --enablerepo '*' -y || true
find . -name .repodata -type d | xargs -r rm -rf

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

for i in base updates extras centosplus cr dotnet; do
for j in =$(uname -i) $([ "_$i" = '_cr' ] || [ "_$i" = '_dotnet' ] || echo '-source=Source') $([ "_$i" = '_base' ] && echo "-debuginfo=debug/$(uname -i)"); do
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
# Intel oneAPI
# ----------------------------------------------------------------

export REPO_TASKS=$(jq <<< "$REPO_TASKS" '.repo_tasks[.repo_tasks | length] |= . +
{
    "repo":         "'"oneAPI"'",
    "path":         "'"intel"'",
    "retries":      10,
    "sync_args":    "--delete --newest-only"
}')

# ----------------------------------------------------------------
# CUDA Repository Mirroring Task
# ----------------------------------------------------------------

for dist in rhel7; do
    name="$(cut -d',' -f1 <<< "$sub_repo,")"
    mkdir -p "nvidia/cuda/$dist/$(uname -i)"
    pushd "$_"
    for attempt in $($DRY || seq 100 -1 0); do
        [ "$attempt" -gt 0 ]
        (
            set -e
            wget $DRY_WGET -ct 1000 "https://developer.download.nvidia.com/compute/cuda/repos/$dist/$(uname -i)/7fa2af80.pub"
            if ! rpm --import "7fa2af80.pub"; then
                echo 'Bad pubkey file:'
                sed 's/^\(.\)/    \1/' '7fa2af80.pub'
                rm -f '7fa2af80.pub'
                exit 1
            fi
        ) && break
        echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
    done
    popd

    export REPO_TASKS=$(jq <<< "$REPO_TASKS" '.repo_tasks[.repo_tasks | length] |= . +
    {
        "repo":         "'"cuda-$dist-$(uname -i)"'",
        "path":         "'"nvidia/cuda/$dist/$(uname -i)"'",
        "retries":      30,
        "use_proxy":    "'"false"'",
    }')
done

for sub_repo in nvidia-machine-learning,machine-learning; do
for dist in rhel7; do
    name="$(cut -d',' -f1 <<< "$sub_repo,")"
    dir="$(cut -d',' -f2 <<< "$sub_repo,")"
    mkdir -p "nvidia/$dir/$dist/$(uname -i)"
    pushd "$_"
    for attempt in $($DRY || seq 100 -1 0); do
        [ "$attempt" -gt 0 ]
        (
            set -e
            wget $DRY_WGET -ct 1000 "https://developer.download.nvidia.com/compute/$dir/repos/$dist/$(uname -i)/7fa2af80.pub"
            if ! rpm --import "7fa2af80.pub"; then
                echo 'Bad pubkey file:'
                sed 's/^\(.\)/    \1/' '7fa2af80.pub'
                rm -f '7fa2af80.pub'
                exit 1
            fi
        ) && break
        echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
    done
    popd

    export REPO_TASKS=$(jq <<< "$REPO_TASKS" '.repo_tasks[.repo_tasks | length] |= . +
    {
        "repo":         "'"$name"'",
        "path":         "'"nvidia/$dir/$dist/$(uname -i)"'",
        "retries":      30,
        "use_proxy":    "'"false"'",
    }')
done
done

for i in libnvidia-container{,-experimental} nvidia-{container-runtime{,-experimental},docker}; do
    mkdir -p "nvidia/$i/centos7/$(uname -i)"
    pushd "$_"
    for attempt in $($DRY || seq 100 -1 0); do
        [ "$attempt" -gt 0 ]
        (
            set -e
            wget $DRY_WGET -cqt 10 "https://nvidia.github.io/$(sed 's/\-experimental//' <<< "$i")/gpgkey"
            if ! rpm --import "gpgkey"; then
                echo 'Bad pubkey file:'
                sed 's/^\(.\)/    \1/' 'gpgkey'
                rm -f 'gpgkey'
                exit 1
            fi
        ) && break
        echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
    done
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
    for attempt in $($DRY || seq 100 -1 0); do
        [ "$attempt" -gt 0 ]
        (
            set -e
            wget $DRY_WGET -cqt 10 "https://download.docker.com/linux/centos/gpg"
            if ! rpm --import "gpg"; then
                echo 'Bad pubkey file:'
                sed 's/^\(.\)/    \1/' 'gpg'
                rm -f 'gpg'
                exit 1
            fi
        ) && break
        echo "Retrying... $(expr "$attempt" - 1) chance(s) left."
    done
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
    JSON_OBJ=$(jq <<< "$REPO_TASKS" ".repo_tasks | .[{}]")
    printf "Execute task\n%s\n" "$JSON_OBJ"

    repo="$(jq -r ".repo" <<< "$JSON_OBJ")"
    path="$(jq -r ".path" <<< "$JSON_OBJ")"
    [ "'"$#"'" -eq 0 ] || grep -i "$repo" <<< "'"$@"'" || exit 0
    jq -e ".sync_args" <<< "$JSON_OBJ" > /dev/null && sync_args=$(jq -r ".sync_args" <<< "$JSON_OBJ")
    retries=1
    jq -e ".retries" <<< "$JSON_OBJ" > /dev/null && retries=$(jq -r ".retries" <<< "$JSON_OBJ")
    use_proxy="'"$USE_PROXY"'"
    jq -e ".use_proxy" <<< "$JSON_OBJ" > /dev/null && use_proxy=$(jq -r ".use_proxy" <<< "$JSON_OBJ")

    mkdir -p "$path"
    repo_bn="$(basename "$repo")"
    mkdir -p "repoid"
    pushd "repoid"
    ln -sfT "../$path" "./$repo_bn"
    "$DRY" || eval $CLEAN_CACHE $repo
    for rest in $(seq "$retries" -1 -1) _; do
        if [ "_$rest" = "__" ]; then
            echo "Failed to download repo after $(expr "$retries" + 1) time(s) of retry."
            exit 1
        fi
        if ([ "$rest" -ge 0 ] && "$use_proxy") || ([ "$rest" -lt 0 ] && ! "$use_proxy") ; then
            export HTTP_PROXY="proxy.codingcafe.org:8118"
            [ "$HTTP_PROXY"  ] && export HTTPS_PROXY="$HTTP_PROXY"
            [ "$HTTP_PROXY"  ] && export http_proxy="$HTTP_PROXY"
            [ "$HTTPS_PROXY" ] && export https_proxy="$HTTPS_PROXY"
        else
            unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
        fi
        unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
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
    pushd "$repo_bn"
    $DRY || eval $CREATEREPO
    popd
    popd
'"'" :::    \
    $(seq 0 $(expr $(jq <<< "$REPO_TASKS" '.repo_tasks | length') - 1)) \
&

# ----------------------------------------------------------------

wait

date

trap - SIGTERM SIGINT EXIT
