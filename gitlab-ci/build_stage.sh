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

    if [ "_$cmd" = "_resume" ] && [ "_$stage" == "_$CI_JOB_STAGE" ]; then
        echo "Resume stage \"$CI_JOB_STAGE\"."
        cat stage/resume > 'Dockerfile'
    else
        echo "Build stage \"$CI_JOB_STAGE\"."
		cat stage/$CI_JOB_STAGE > 'Dockerfile'
	fi

    cat 'Dockerfile' > "stage/$CI_JOB_STAGE"

	if [ "_$stage" = "_$CI_JOB_STAGE" ]; then
		cat "stage/$CI_JOB_STAGE" > 'Dockerfile'
    else
		grep -v '"/etc/codingcafe/scripts"' "stage/$CI_JOB_STAGE" > 'Dockerfile'
	fi

	if time docker build                                \
        --cpu-shares 128                                \
        --no-cache                                      \
        --pull                                          \
        --squash                                        \
        --tag "$CI_REGISTRY_IMAGE:stage-$CI_JOB_STAGE"  \
        .; then
        time docker push "$CI_REGISTRY_IMAGE:stage-$CI_JOB_STAGE"
    else
        echo 'Docker build failed. Save breakpoint snapshot.'
        time docker commit "$(docker ps -alq)" "$CI_REGISTRY_IMAGE:breakpoint"
        time docker push "$_"
    fi
fi
