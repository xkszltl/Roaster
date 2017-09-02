#!/bin/bash

# ================================================================
# Repo Cache
# ================================================================

set -e
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# ----------------------------------------------------------------

export http_proxy=127.0.0.1:8118
export HTTP_PROXY=$http_proxy
export https_proxy=$http_proxy
export HTTPS_PROXY=$https_proxy

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
    --update
    --workers $(nproc)
    $(pwd)
'

# ----------------------------------------------------------------

mkdir -p /var/www/repos
cd $_

(
    set -e
    rsync -avPz --delete --address 10.0.0.12 rsync://rsync.mirrors.ustc.edu.cn/CTAN/ CTAN    \
    || rsync -avPz --delete --address 10.0.0.11 rsync://mirrors.tuna.tsinghua.edu.cn/CTAN/ CTAN
) &

for i in $(find . -name .repodata -type d); do :
(
    set -e
    rm -rf $i
) &
done

(
    set -e
    yum makecache fast -y || true
) &

wait

# ----------------------------------------------------------------

for i in base updates extras centosplus; do :
for j in =$(uname -i) -source=Source $([ $i = base ] && echo -debuginfo=debug/$(uname -i)); do :
(
    set -e
    mkdir -p centos/7/$i/$(sed 's/.*=//' <<< $j)
    cd $_
    eval $REPOSYNC $i$(sed 's/=.*//' <<< $j) || true
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
    eval $REPOSYNC epel$(sed 's/=.*//' <<< $i) || true
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
    eval $REPOSYNC centos-sclo-$i$(sed 's/=.*//' <<< $j) || true
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
    eval $REPOSYNC $i || true
    eval $CREATEREPO
) &
done

# ----------------------------------------------------------------

(
    set -e
    mkdir -p cuda/rhel7/$(uname -i)
    cd $_
    wget -cq https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/7fa2af80.pub
    rpm --import 7fa2af80.gpg
    eval $REPOSYNC cuda
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
    eval $REPOSYNC docker-ce-$j$(sed 's/=.*//' <<< $i)
    eval $CREATEREPO
    eval $REPOSYNC docker-ce-$j$(sed 's/=.*//' <<< $i) --delete
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
    eval $REPOSYNC $(sed 's/=.*//' <<< $i)_$(sed 's/.*=//' <<< $i)$(sed 's/=.*//' <<< $j) $([ $(sed 's/=.*//' <<< $i) = gitlab ] && echo '--newest-only')
    eval $CREATEREPO
) &
done
done

# ----------------------------------------------------------------

wait
trap - SIGTERM SIGINT EXIT
