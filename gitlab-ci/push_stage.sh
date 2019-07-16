#!/bin/bash

set -xe

[ "$BASE_DISTRO" ] || BASE_DISTRO=centos

# [ "$GITLAB_CI" ]
[ "$CI_JOB_STAGE" ]
[ "$CI_REGISTRY_IMAGE" ]

time sudo docker push "$CI_REGISTRY_IMAGE/$BASE_DISTRO:stage-$(sed 's/^[^-]*-//' <<< "$CI_JOB_STAGE")"
