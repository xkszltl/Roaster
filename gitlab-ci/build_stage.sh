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
	time docker build                                   \
        --cpu-shares 128                                \
        --no-cache                                      \
        --pull                                          \
        --rm                                            \
        --tag $CI_REGISTRY_IMAGE:stage-$CI_JOB_STAGE    \
        .

	# time docker-squash -v $CI_REGISTRY_IMAGE:stage-$CI_JOB_STAGE -t stage-$CI_JOB_STAGE
	time docker push $CI_REGISTRY_IMAGE:stage-$CI_JOB_STAGE
fi
