#!/bin/bash

# ================================================================
# Repo Cache
# ================================================================

mkdir -p /var/www/repos/centos/7/{base,updates,extras,centosplus}/{$(uname -i),Source}
mkdir -p /var/www/repos/centos/7/base/$(uname -i)/debug
ln -sf /var/www/repos/centos/7/base /var/www/repos/centos/7/os

mkdir -p /var/www/repos/epel/7/{$(uname -i){,/debug},SRPMS}

mkdir -p /var/www/repos/cuda/rhel7/$(uname -i)

mkdir -p /var/www/repos/gitlab/gitlab-{ce,ci-multi-runner}/el/7/{$(uname -i),SRPMS}

# ----------------------------------------------------------------

for i in centos/7/{{base,updates,extras,centosplus}/{$(uname -i),Source},base/$(uname -i)/debug} epel/7/{$(uname -i){,/debug},SRPMS} cuda/rhel7/$(uname -i) gitlab/gitlab-{ce,ci-multi-runner}/el/7/{$(uname -i),SRPMS}; do
    createrepo -p --workers=16 /var/www/repos/$i
    # gpg -ab /var/www/repos/$i/repodata/repomd.xml
done

# ----------------------------------------------------------------

for i in $(basename -a $(find /var/www/repos/centos/7 -mindepth 1 -maxdepth 1 -type d) | sort); do
    reposync --download-metadata --norepopath --source -gtlm -r $i -p /var/www/repos/centos/7/$i/$(uname -i) && createrepo -p --workers=16 --update /var/www/repos/centos/7/$i/$(uname -i)
    reposync --download-metadata --norepopath --source -gtlm -r $i-source -p /var/www/repos/centos/7/$i/Source && createrepo -p --workers=16 --update /var/www/repos/centos/7/$i/Source
done
reposync --download-metadata --norepopath --source -gtlm -r base-debuginfo -p /var/www/repos/centos/7/base/$(uname -i)/debug && createrepo -p --workers=16 --update /var/www/repos/centos/7/base/$(uname -i)/debug

# ----------------------------------------------------------------

reposync --download-metadata --norepopath --source -gtlm -r epel -p /var/www/repos/epel/7/$(uname -i) && createrepo -p --workers=16 --update /var/www/repos/epel/7/$(uname -i)
reposync --download-metadata --norepopath --source -gtlm -r epel-debuginfo -p /var/www/repos/epel/7/$(uname -i)/debug && createrepo -p --workers=16 --update /var/www/repos/epel/7/$(uname -i)/debug
reposync --download-metadata --norepopath --source -gtlm -r epel-source -p /var/www/repos/epel/7/SRPMS && createrepo -p --workers=16 --update /var/www/repos/epel/7/SRPMS

# ----------------------------------------------------------------

wget -cqP /var/www/repos/cuda/rhel7/$(uname -i) http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/7fa2af80.pub
reposync --download-metadata --norepopath --source -gtlm -r cuda -p /var/www/repos/cuda/rhel7/$(uname -i) && createrepo -p --workers=16 --update /var/www/repos/cuda/rhel7/$(uname -i)

# ----------------------------------------------------------------

reposync --download-metadata --norepopath --source -gtlm -r gitlab_gitlab-ce -p /var/www/repos/gitlab/gitlab-ce/el/7/$(uname -i) && createrepo -p --workers=16 --update /var/www/repos/gitlab/gitlab-ce/el/7/$(uname -i)
reposync --download-metadata --norepopath --source -gtlm -r gitlab_gitlab-ce-source -p /var/www/repos/gitlab/gitlab-ce/el/7/SRPMS && createrepo -p --workers=16 --update /var/www/repos/gitlab/gitlab-ce/el/7/SRPMS

reposync --download-metadata --norepopath --source -gtlm -r runner_gitlab-ci-multi-runner -p /var/www/repos/gitlab/gitlab-ci-multi-runner/el/7/$(uname -i) && createrepo -p --workers=16 --update /var/www/repos/gitlab/gitlab-ci-multi-runner/el/7/$(uname -i)
reposync --download-metadata --norepopath --source -gtlm -r runner_gitlab-ci-multi-runner-source -p /var/www/repos/gitlab/gitlab-ci-multi-runner/el/7/SRPMS && createrepo -p --workers=16 --update /var/www/repos/gitlab/gitlab-ci-multi-runner/el/7/SRPMS
