#!/bin/bash

set -xe

if [ ! "$CI_REGISTRY_IMAGE" ]; then
    echo "Please set environment variable CI_REGISTRY_IMAGE to a docker registry."
    exit 1
fi

if [ ! "$LOG_FILE" ]; then
    mkdir -p log
    export LOG_FILE="$(readlink -f "$(date -u '+log/%Y-%m-%d_%H-%M-%S.log')")"
    "$(which time)" -v "$0" 2>&1 | tee "$LOG_FILE"
    exit 0
fi

export CI_COMMIT_REF_NAME=build-init

for CI_JOB_STAGE in init repo font pkg-skip tex ss infra llvm util misc dl edit finish; do
    export CI_JOB_STAGE

    case "$CI_JOB_STAGE" in
    edit)
        [ "$PREV_CI_JOB_STAGE" ]
        sudo docker tag "$CI_REGISTRY_IMAGE/centos:stage-"{"$PREV_CI_JOB_STAGE","$CI_JOB_STAGE"}
        sudo docker push "$CI_REGISTRY_IMAGE/centos:stage-$CI_JOB_STAGE"
        ;;
    finish)
        [ "$PREV_CI_JOB_STAGE" ]
        sudo docker tag "$CI_REGISTRY_IMAGE/centos:"{"stage-$PREV_CI_JOB_STAGE",latest}
        sudo docker push "$CI_REGISTRY_IMAGE/centos:latest"
        ;;
    *)
        gitlab-ci/build_stage.sh
        ;;
    esac

    PREV_CI_JOB_STAGE="$CI_JOB_STAGE"
done