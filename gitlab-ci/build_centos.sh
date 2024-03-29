#!/bin/bash

set -xe

cd "$(dirname "$0")/.."

if [ ! "$CI_REGISTRY_IMAGE" ]; then
    printf '\033[31m[ERROR] Please set environment variable CI_REGISTRY_IMAGE to a docker registry.\033[0m\n' >&2
    exit 1
fi

if [ ! "$LOG_FILE" ]; then
    mkdir -p log
    export LOG_FILE="$(readlink -f "$(date -u '+log/%Y-%m-%d_%H-%M-%S.log')")"
    "$(which time)" -v "$0" 2>&1 | tee "$LOG_FILE"
    exit 0
fi

export BASE_DISTRO=centos

[ "$CI_COMMIT_REF_NAME" ] || export CI_COMMIT_REF_NAME=build-init

for CI_JOB_STAGE in init repo font pkg-{stable,skip,all} auth tex ss intel infra llvm util misc dl ort edit anneal finish; do
    export CI_JOB_STAGE

    if [ ! "$FIRST_STAGE" ] && [ "_$(sed 's/^[^\-]*\-//' <<< "$CI_COMMIT_REF_NAME")" != "_$CI_JOB_STAGE" ]; then
        PREV_CI_JOB_STAGE="$CI_JOB_STAGE"
        continue
    fi
    [ "$FIRST_STAGE" ] || FIRST_STAGE="$CI_JOB_STAGE"

    case "$CI_JOB_STAGE" in
    anneal)
        [ "$PREV_CI_JOB_STAGE" ]
        src="$CI_REGISTRY_IMAGE/$BASE_DISTRO:stage-$PREV_CI_JOB_STAGE"  \
        dst="$CI_REGISTRY_IMAGE/$BASE_DISTRO:stage-$CI_JOB_STAGE"       \
        ./docker_anneal.sh
        CI_JOB_NAME="push-$CI_JOB_STAGE" gitlab-ci/push_stage.sh &
        ;;
    finish)
        [ "$PREV_CI_JOB_STAGE" ]
        sudo docker tag "$CI_REGISTRY_IMAGE/$BASE_DISTRO:"{"stage-$PREV_CI_JOB_STAGE",latest}
        sudo docker push "$CI_REGISTRY_IMAGE/$BASE_DISTRO:latest"
        sudo docker rmi "$CI_REGISTRY_IMAGE/$BASE_DISTRO:breakpoint" 2>/dev/null || true
        ;;
    *)
        gitlab-ci/build_stage.sh
        CI_JOB_NAME="push-$CI_JOB_STAGE" gitlab-ci/push_stage.sh &
        ;;
    esac

    PREV_CI_JOB_STAGE="$CI_JOB_STAGE"
done
wait

printf '\033[32m[INFO] Image "%s" is ready.\033[0m\n' "$CI_REGISTRY_IMAGE/$BASE_DISTRO" >&2
