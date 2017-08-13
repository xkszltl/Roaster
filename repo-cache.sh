#!/bin/bash

# ================================================================
# Repo Cache
# ================================================================

set -e
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# ----------------------------------------------------------------

REPOSYNC='reposync
    --cachedir=$(mktemp -d)
    --download-metadata
    --downloadcomps
    --gpgcheck
    --norepopath
    --plugin
    --source
    -r
'

CREATEREPO='createrepo_c
    --cachedir=.cache
    --checksum=sha512
    --compress-type=xz
    --database
    $([ -f comps.xml ] && echo --groupfile=comps.xml)
    --pretty
    --update
    --workers $(nproc)
    $(pwd)
'

# ----------------------------------------------------------------

mkdir -p /var/www/repos
cd $_

for i in $(find . -name .repodata -type d); do
(
    set -e
    rm -rf $i
) &
done

(
    set -e
    yum makecache fast || true
) &

wait

# ----------------------------------------------------------------

for i in base updates extras centosplus; do
for j in =$(uname -i) -source=Source $([ $i = base ] && echo -debuginfo=debug/$(uname -i)); do
(
    set -e
    mkdir -p centos/7/$i/$(sed 's/.*=//' <<< $j)
    cd $_
    eval $REPOSYNC $i$(sed 's/=.*//' <<< $j)
    eval $CREATEREPO
) &
done
done

ln -sf centos/7/{base,os}

# ----------------------------------------------------------------

for i in {=,-debuginfo=debug/}$(uname -i) -source=SRPMS; do
(
    set -e
    mkdir -p epel/7/$(sed 's/.*=//' <<< $i)
    cd $_
    eval $REPOSYNC epel$(sed 's/=.*//' <<< $i)
    eval $CREATEREPO
) &
done

# ----------------------------------------------------------------

for i in sclo rh; do
for j in =$(uname -i)/$i -testing=$(uname -i)/$i/testing -source=Source/$i -debuginfo=$(uname -i)/$i/debuginfo; do
(
    set -e
    mkdir -p centos/7/sclo/$(sed 's/.*=//' <<< $j)
    cd $_
    eval $REPOSYNC centos-sclo-$i$(sed 's/=.*//' <<< $j)
    eval $CREATEREPO
) &
done
done

# ----------------------------------------------------------------

for i in elrepo{,-testing,-kernel,-extras}; do
(
    set -e
    mkdir -p $(sed 's/-/\//' <<< $i)/el7
    cd $_
    eval $REPOSYNC $i
    eval $CREATEREPO
) &
done

# ----------------------------------------------------------------

(
    set -e
    mkdir -p cuda/rhel7/$(uname -i)
    cd $_
    wget -cq https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/7fa2af80.pub
    eval $REPOSYNC cuda
    eval $CREATEREPO
) &

# ----------------------------------------------------------------

for i in {=,-debuginfo=debug-}$(uname -i) -source=source; do
for j in stable edge test; do
(
    set -e
    mkdir -p docker/linux/centos/7/$(sed 's/.*=//' <<< $i)/$j
    cd $_
    eval $REPOSYNC docker-ce-$j$(sed 's/=.*//' <<< $i)
    eval $CREATEREPO
    eval $REPOSYNC docker-ce-$j$(sed 's/=.*//' <<< $i) --delete
    eval $CREATEREPO
) &
done
done

# ----------------------------------------------------------------

for i in gitlab=gitlab-ce runner=gitlab-ci-multi-runner; do
for j in =$(uname -i) -source=SRPMS; do
(
    set -e
    mkdir -p gitlab/$(sed 's/.*=//' <<< $i)/el/7/$(sed 's/.*=//' <<< $j)
    cd $_
    eval $REPOSYNC $(sed 's/=.*//' <<< $i)_$(sed 's/.*=//' <<< $i)$(sed 's/=.*//' <<< $j)
    eval $CREATEREPO
) &
done
done

# ----------------------------------------------------------------

wait
trap - SIGTERM SIGINT EXIT
