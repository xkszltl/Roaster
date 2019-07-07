#!/bin/bash

set -xe

[ "$BASE_DISTRO" ] || BASE_DISTRO=centos

# [ "$GITLAB_CI" ]
[ "$CI_COMMIT_REF_NAME" ]
[ "$CI_JOB_STAGE" ]
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

cmd="$(sed 's/-.*//' <<< "$CI_COMMIT_REF_NAME")";
stage="$(sed 's/^[^\-]*-//' <<< "$CI_COMMIT_REF_NAME")";

if [ "_$cmd" = "_resume" ] && [ "_$stage" = "_$CI_JOB_STAGE" ]; then
    echo "Resume stage \"$CI_JOB_STAGE\"."
    cat "docker/$BASE_DISTRO/resume" > 'Dockerfile'
else
    echo "Build stage \"$CI_JOB_STAGE\"."
    cat "docker/$BASE_DISTRO/$CI_JOB_STAGE" > 'Dockerfile'
fi

sed -i "s/^FROM docker\.codingcafe\.org\/.*:/FROM $(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$CI_REGISTRY_IMAGE/$BASE_DISTRO"):/" 'Dockerfile'

[ "_$stage" = "_$CI_JOB_STAGE" ] || sed -i 's/^[[:space:]]*COPY[[:space:]].*"\/etc\/roaster\/scripts".*//' 'Dockerfile'

LABEL_BUILD_ID="$(uuidgen)"

#     --cpu-shares 128
if time sudo DOCKER_BUILDKIT=1 docker build                     \
    --add-host 'docker.codingcafe.org:10.0.0.10'                \
    --add-host 'repo.codingcafe.org:10.0.0.10'                  \
    --add-host 'proxy.codingcafe.org:10.0.0.10'                 \
    --build-arg "BUILD_ID=$LABEL_BUILD_ID"                      \
    --label "BUILD_TIME=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"       \
    --no-cache                                                  \
    --pull                                                      \
    --tag "$CI_REGISTRY_IMAGE/$BASE_DISTRO:stage-$CI_JOB_STAGE" \
    .; then
    time sudo docker push "$CI_REGISTRY_IMAGE/$BASE_DISTRO:stage-$CI_JOB_STAGE"
else
    echo 'Docker build failed. Save breakpoint snapshot.' 1>&2
    DUMP_ID="$(sudo docker ps -aq --filter="label=BUILD_ID=$LABEL_BUILD_ID" --filter="status=exited" | head -n1)"
    if [ "$DUMP_ID" ]; then
        time sudo docker commit "$DUMP_ID" "$CI_REGISTRY_IMAGE/$BASE_DISTRO:breakpoint"
        time sudo docker push "$_"
        echo "Failed to build. Dump container is saved as breakpoint."
    else
       echo "Dump container with BUILD_ID=$LABEL_BUILD_ID is not found."
    fi
    exit 1
fi
