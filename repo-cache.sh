#!/bin/bash

# ================================================================
# Repo Cache
# ================================================================

set -e

# ----------------------------------------------------------------

mkdir -p                                                                            \
    /var/www/repos/centos/7/{base,updates,extras,centosplus}/{`uname -i`,Source}    \
    /var/www/repos/centos/7/base/debug/`uname -i`                                   \
    /var/www/repos/epel/7/{{,debug/}`uname -i`,SRPMS}                               \
    /var/www/repos/cuda/rhel7/`uname -i`                                            \
    /var/www/repos/gitlab/gitlab-{ce,ci-multi-runner}/el/7/{`uname -i`,SRPMS}

ln -sf /var/www/repos/centos/7/base /var/www/repos/centos/7/os

# ----------------------------------------------------------------

for i in $(basename -a $(find /var/www/repos/centos/7 -mindepth 1 -maxdepth 1 -type d) | sort); do
    (
        reposync --download-metadata --norepopath --plugin --source -gtlm -e `mktemp -d` -r $i -p /var/www/repos/centos/7/$i/`uname -i` &&                  \
        createrepo -p -s sha512 --compress-type xz --workers 16 --profile --update /var/www/repos/centos/7/$i/`uname -i`                                    \
    ) &

    (
        reposync --download-metadata --norepopath --plugin --source -gtlm -e `mktemp -d` -r $i-source -p /var/www/repos/centos/7/$i/Source &&               \
        createrepo -p -s sha512 --compress-type xz --workers 16 --profile --update /var/www/repos/centos/7/$i/Source                                        \
    ) &
done

(
    reposync --download-metadata --norepopath --plugin --source -gtlm -e `mktemp -d` -r base-debuginfo -p /var/www/repos/centos/7/base/debug/`uname -i` &&  \
    createrepo -p -s sha512 --compress-type xz --workers 16 --profile --update /var/www/repos/centos/7/base/debug/`uname -i`                                \
) &

# ----------------------------------------------------------------

(
    reposync --download-metadata --norepopath --plugin --source -gtlm -e `mktemp -d` -r epel -p /var/www/repos/epel/7/`uname -i` &&                         \
    createrepo -p -s sha512 --compress-type xz --workers 16 --profile --update /var/www/repos/epel/7/`uname -i`                                             \
) &

(
    reposync --download-metadata --norepopath --plugin --source -gtlm -e `mktemp -d` -r epel-debuginfo -p /var/www/repos/epel/7/debug/`uname -i` &&         \
    createrepo -p -s sha512 --compress-type xz --workers 16 --profile --update /var/www/repos/epel/7/debug/`uname -i`                                       \
) &

(
    reposync --download-metadata --norepopath --plugin --source -gtlm -e `mktemp -d` -r epel-source -p /var/www/repos/epel/7/SRPMS &&                       \
    createrepo -p -s sha512 --compress-type xz --workers 16 --profile --update /var/www/repos/epel/7/SRPMS                                                  \
)&

# ----------------------------------------------------------------

(
    wget -cqP /var/www/repos/cuda/rhel7/`uname -i` http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/7fa2af80.pub && \
    reposync --download-metadata --norepopath --plugin --source -gtlm -e `mktemp -d` -r cuda -p /var/www/repos/cuda/rhel7/`uname -i` && \
    createrepo -p -s sha512 --compress-type xz --workers 16 --profile --update /var/www/repos/cuda/rhel7/`uname -i`                     \
) &

# ----------------------------------------------------------------

(
    reposync --download-metadata --norepopath --plugin --source -gtlm -e `mktemp -d` -r gitlab_gitlab-ce -p /var/www/repos/gitlab/gitlab-ce/el/7/`uname -i` &&      \
    createrepo -p -s sha512 --compress-type xz --workers 16 --profile --update /var/www/repos/gitlab/gitlab-ce/el/7/`uname -i`                                      \
) &

(
    reposync --download-metadata --norepopath --plugin --source -gtlm -e `mktemp -d` -r gitlab_gitlab-ce-source -p /var/www/repos/gitlab/gitlab-ce/el/7/SRPMS &&    \
    createrepo -p -s sha512 --compress-type xz --workers 16 --profile --update /var/www/repos/gitlab/gitlab-ce/el/7/SRPMS                                           \
) &

(
    reposync --download-metadata --norepopath --plugin --source -gtlm -e `mktemp -d` -r runner_gitlab-ci-multi-runner -p /var/www/repos/gitlab/gitlab-ci-multi-runner/el/7/`uname -i` &&    \
    createrepo -p -s sha512 --compress-type xz --workers 16 --profile --update /var/www/repos/gitlab/gitlab-ci-multi-runner/el/7/`uname -i`                                                 \
) &

(
    reposync --download-metadata --norepopath --plugin --source -gtlm -e `mktemp -d` -r runner_gitlab-ci-multi-runner-source -p /var/www/repos/gitlab/gitlab-ci-multi-runner/el/7/SRPMS &&  \
    createrepo -p -s sha512 --compress-type xz --workers 16 --profile --update /var/www/repos/gitlab/gitlab-ci-multi-runner/el/7/SRPMS                                                      \
) &

wait
