#!/bin/bash

# ================================================================
# Repo Cache
# ================================================================

set -e

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

CREATEREPO='createrepo
    --cachedir=.cache
    --checksum=sha512
    --compress-type=xz
    $([ -f comps.xml ] && echo --groupfile=comps.xml)
    --pretty
    --profile
    --update
    --workers $(nproc)
    $(pwd)
'

# ----------------------------------------------------------------

cd /var/www/repos

mkdir -p                                                            \
    centos/7/{base,updates,extras,centosplus}/{$(uname -i),Source}  \
    centos/7/base/debug/$(uname -i)                                 \
    epel/7/{{,debug/}$(uname -i),SRPMS}                             \
    cuda/rhel7/$(uname -i)                                          \
    gitlab/gitlab-{ce,ci-multi-runner}/el/7/{$(uname -i),SRPMS}

ln -sf centos/7/base centos/7/os

# ----------------------------------------------------------------

for i in $(basename -a $(find centos/7 -mindepth 1 -maxdepth 1 -type d) | sort); do
for j in =$(uname -i) -source=Source $([ $i = base ] && echo -debuginfo=debug/$(uname -i)); do
(
    set -e
    cd centos/7/$i/$(sed 's/.*=//' <<< $j)
    eval $REPOSYNC $i$(sed 's/=.*//' <<< $j)
    eval $CREATEREPO
) &
done
done

# ----------------------------------------------------------------

for i in {=,-debuginfo=debug/}$(uname -i) -source=SRPMS; do
(
    set -e
    cd epel/7/$(sed 's/.*=//' <<< $i)
    eval $REPOSYNC epel$(sed 's/=.*//' <<< $i)
    eval $CREATEREPO
) &
done

# ----------------------------------------------------------------

(
    set -e
    cd cuda/rhel7/$(uname -i)
    wget -cq https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/7fa2af80.pub
    eval $REPOSYNC cuda
    eval $CREATEREPO
) &

# ----------------------------------------------------------------

for i in gitlab=gitlab-ce runner=gitlab-ci-multi-runner; do
for j in =$(uname -i) -source=SRPMS; do
(
    set -e
    cd gitlab/$(sed 's/.*=//' <<< $i)/el/7/$(sed 's/.*=//' <<< $j)
    eval $REPOSYNC $(sed 's/=.*//' <<< $i)_$(sed 's/.*=//' <<< $i)$(sed 's/=.*//' <<< $j)
    eval $CREATEREPO
) &
done
done

# ----------------------------------------------------------------

wait
