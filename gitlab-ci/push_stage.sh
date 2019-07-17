#!/bin/bash

set -xe

[ "$BASE_DISTRO" ] || BASE_DISTRO=centos

# [ "$GITLAB_CI" ]
[ "$CI_JOB_NAME" ]
[ "$CI_REGISTRY_IMAGE" ]

set +x
if [ "$CI_REGISTRY" ] && [ "$CI_REGISTRY_USER" ] && [ "$CI_REGISTRY_PASSWORD" ]; then
    sudo docker login                   \
        --password-stdin                \
        --username "$CI_REGISTRY_USER"  \
        "$CI_REGISTRY"                  \
    <<< "$CI_REGISTRY_PASSWORD"
fi
set -x

time sudo docker push "$CI_REGISTRY_IMAGE/$BASE_DISTRO:stage-$(sed 's/^[^\-]*\-//' <<< "$CI_JOB_NAME")"
