#!/bin/bash

set -e

if [ $GITLAB_CI ]; then
	docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY

	if [ $(echo $CI_COMMIT_REF_NAME | sed 's/^[^\-]*-//') = $CI_JOB_STAGE ]; then
		cat stage/$CI_JOB_STAGE > Dockerfile
	else
		grep -v ADD stage/$CI_JOB_STAGE > Dockerfile
	fi
	docker build --pull --no-cache --cpu-shares 128 -t $CI_REGISTRY_IMAGE:stage-$CI_JOB_STAGE .

	docker push $CI_REGISTRY_IMAGE:stage-$CI_JOB_STAGE
fi
