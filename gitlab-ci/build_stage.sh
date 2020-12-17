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

GENERATED_DOCKERFILE="$(mktemp --tmpdir 'Dockerfile.generated.XXXXXXXX')"

if [ "_$cmd" = "_resume" ] && [ "_$stage" = "_$CI_JOB_STAGE" ]; then
    echo "Resume stage \"$CI_JOB_STAGE\"."
    cat "docker/$BASE_DISTRO/resume" > "$GENERATED_DOCKERFILE"
else
    echo "Build stage \"$CI_JOB_STAGE\"."
    cat "docker/$BASE_DISTRO/$CI_JOB_STAGE" > "$GENERATED_DOCKERFILE"
fi

sed -i "s/^FROM docker\.codingcafe\.org\/.*:/FROM $(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$CI_REGISTRY_IMAGE/$BASE_DISTRO"):/" "$GENERATED_DOCKERFILE"

[ "_$stage" = "_$CI_JOB_STAGE" ] || sed -i 's/^[[:space:]]*COPY[[:space:]].*"\/etc\/roaster\/scripts".*//' "$GENERATED_DOCKERFILE"

# Use latest buildkit frontend.
# If buildkit doesn't work properly, try docker-ce-nightly and match it with nightly frontend.
# sed -i 's/^\([[:space:]]*#[[:space:]]*syntax=docker\/dockerfile\):\(experimental[[:space:]]*\)$/\1\-upstream:master\-\2/' "$GENERATED_DOCKERFILE"

# Drop experimental syntax on newer version.
# sed -i 's/^\([[:space:]]*#[[:space:]]*syntax=docker\/dockerfile:experimental[[:space:]]*\)$//' "$GENERATED_DOCKERFILE"

BUILD_LOG="$(mktemp --tmpdir 'roaster-docker-build.XXXXXXXXXX.log')"
for retry in $(seq 100 -1 0); do
    if [ "$retry" -le 0 ]; then
        rm -rf "$BUILD_LOG" "$GENERATED_DOCKERFILE"
        echo "Out of retries."
        exit 1
    fi

    LABEL_BUILD_ID="$(uuidgen)"
    (
        set -xe
        #     --cpu-shares 128
        sudo                                                            \
            DOCKER_BUILDKIT=1                                           \
            docker build                                                \
            --add-host 'docker.codingcafe.org:10.0.0.10'                \
            --add-host 'proxy.codingcafe.org:10.0.0.10'                 \
            --add-host 'repo.codingcafe.org:10.0.0.10'                  \
            --build-arg LABEL_BUILD_ID="$LABEL_BUILD_ID"                \
            --file "$GENERATED_DOCKERFILE"                              \
            --label "BUILD_TIME=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"       \
            --no-cache                                                  \
            --progress plain                                            \
            $([ "_$stage" = "_$CI_JOB_STAGE" ] && echo '--pull')        \
            $([ -e 'cred/env-cred-usr.sh' ] &&  echo '--secret id=env-cred-usr,src=cred/env-cred-usr.sh') \
            --tag "$CI_REGISTRY_IMAGE/$BASE_DISTRO:stage-$CI_JOB_STAGE" \
            .
        printf "\nExited with code %d.\n" "$?"
    ) 2>&1 | tee "$BUILD_LOG"
    DUMP_ID="$(sudo docker ps -aq --filter="label=BUILD_ID=$LABEL_BUILD_ID" --filter="status=exited" | head -n1)"

    # Success
    if [ "_$(tail -n1 "$BUILD_LOG")" = '_Exited with code 0.' ]; then
        [ "$DUMP_ID" ] && time sudo docker rm "$DUMP_ID"
        break
    fi

    # Work around docker buildkit issue: https://github.com/moby/buildkit/issues/1309
    if grep 'failed to solve with frontend dockerfile.v0: failed to solve with frontend gateway.v0: frontend grpc server closed unexpectedly' "$BUILD_LOG"; then
        echo "Docker buildkit issue. $(expr "$retry" - 1) retries remaining."
        continue
    fi

    echo 'Docker build failed. Save breakpoint snapshot.' 1>&2
    if [ "$DUMP_ID" ]; then
        time sudo docker commit "$DUMP_ID" "$CI_REGISTRY_IMAGE/$BASE_DISTRO:breakpoint"
        time sudo docker push "$_"
        echo "Failed to build. Dump container is saved as breakpoint."
    else
        echo "Dump container with BUILD_ID=$LABEL_BUILD_ID is not found."
    fi
    rm -rf "$BUILD_LOG" "$GENERATED_DOCKERFILE"
    exit 1
done
rm -rf "$BUILD_LOG" "$GENERATED_DOCKERFILE"
