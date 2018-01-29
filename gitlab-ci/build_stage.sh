#!/bin/bash

set -e

if [ $GITLAB_CI ]; then
	docker login                        \
        --password-stdin                \
        --username $CI_REGISTRY_USER    \
        $CI_REGISTRY                    \
    <<<$CI_REGISTRY_PASSWORD

	if [ $(echo $CI_COMMIT_REF_NAME | sed 's/^[^\-]*-//') = $CI_JOB_STAGE ]; then
		cat stage/$CI_JOB_STAGE
	else
		grep -v '"/etc/codingcafe/scripts"' stage/$CI_JOB_STAGE
	fi > Dockerfile
	docker build                                        \
        --cpu-shares 128                                \
        --no-cache                                      \
        --pull                                          \
        --rm                                            \
        --tag $CI_REGISTRY_IMAGE:stage-$CI_JOB_STAGE    \
        .

	docker push $CI_REGISTRY_IMAGE:stage-$CI_JOB_STAGE
fi
