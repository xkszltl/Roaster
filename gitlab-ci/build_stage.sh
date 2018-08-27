#!/bin/bash

set -xe

if [ $GITLAB_CI ]; then
	docker login                        \
        --password-stdin                \
        --username $CI_REGISTRY_USER    \
        $CI_REGISTRY                    \
    <<< "$CI_REGISTRY_PASSWORD"

    cmd="$(sed 's/-.*//' <<< "$CI_COMMIT_REF_NAME")";
    stage="$(sed 's/^[^\-]*-//' <<< "$CI_COMMIT_REF_NAME")";

	if [ "_$cmd" = "_build" ]; then
        echo "Build stage \"$CI_JOB_STAGE\"."
		cat stage/$CI_JOB_STAGE > 'Dockerfile'
    elif [ "_$cmd" = "_resume" ]; then
        echo "Resume stage \"$CI_JOB_STAGE\"."
        cat stage/resume > 'Dockerfile'
    else
        echo "Unknown command \"$cmd\"."
	fi

    cat 'Dockerfile' > "stage/$CI_JOB_STAGE"

	if [ "_$stage" = "_$CI_JOB_STAGE" ]; then
		cat "stage/$CI_JOB_STAGE" > 'Dockerfile'
    else
		grep -v '"/etc/codingcafe/scripts"' "stage/$CI_JOB_STAGE" > 'Dockerfile'
	fi

	time docker build                                   \
        --cpu-shares 128                                \
        --no-cache                                      \
        --pull                                          \
        --squash                                        \
        --tag "$CI_REGISTRY_IMAGE:stage-$CI_JOB_STAGE"  \
        .

    if [ "$?" -eq 0 ]; then
        time docker push "$CI_REGISTRY_IMAGE:stage-$CI_JOB_STAGE"
    else
        echo 'Docker build failed. Save breakpoint snapshot.'
        time docker commit "$(docker ps -alq)" "$CI_REGISTRY_IMAGE:breakpoint"
        time docker push "$CI_REGISTRY_IMAGE:breakpoint"
    fi
fi
