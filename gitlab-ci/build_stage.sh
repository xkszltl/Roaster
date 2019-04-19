#!/bin/bash

set -xe

# [ "$GITLAB_CI" ]
[ "$CI_COMMIT_REF_NAME" ]
[ "$CI_JOB_STAGE" ]
[ "$CI_REGISTRY_IMAGE/centos" ]

set +x
if [ "$CI_REGISTRY" ] && [ "$CI_REGISTRY_USER" ] && [ "$CI_REGISTRY_PASSWORD" ]; then
    docker login                        \
        --password-stdin                \
        --username "$CI_REGISTRY_USER"  \
        "$CI_REGISTRY"                  \
    <<< "$CI_REGISTRY_PASSWORD"
fi
set -x

cmd="$(sed 's/-.*//' <<< "$CI_COMMIT_REF_NAME")";
stage="$(sed 's/^[^\-]*-//' <<< "$CI_COMMIT_REF_NAME")";

if [ "_$cmd" = "_resume" ] && [ "_$stage" == "_$CI_JOB_STAGE" ]; then
    echo "Resume stage \"$CI_JOB_STAGE\"."
    cat stage/resume > 'Dockerfile'
else
    echo "Build stage \"$CI_JOB_STAGE\"."
    cat stage/$CI_JOB_STAGE > 'Dockerfile'
fi

sed -i "s/^FROM docker\.codingcafe\.org\/.*:/FROM $(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$CI_REGISTRY_IMAGE/centos"):/" 'Dockerfile'
cat 'Dockerfile' > "stage/$CI_JOB_STAGE"

if [ "_$stage" = "_$CI_JOB_STAGE" ]; then
    cat "stage/$CI_JOB_STAGE" > 'Dockerfile'
else
    grep -v '"/etc/roaster/scripts"' "stage/$CI_JOB_STAGE" > 'Dockerfile'
fi

if time docker build                                \
    --cpu-shares 128                                \
    --no-cache                                      \
    --pull                                          \
    --tag "$CI_REGISTRY_IMAGE/centos:stage-$CI_JOB_STAGE"  \
    .; then
    time docker push "$CI_REGISTRY_IMAGE/centos:stage-$CI_JOB_STAGE"
else
    echo 'Docker build failed. Save breakpoint snapshot.' 1>&2
    time docker commit "$(docker ps -alq)" "$CI_REGISTRY_IMAGE/centos:breakpoint"
    time docker push "$_"
    exit 1
fi
