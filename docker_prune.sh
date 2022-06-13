#!/bin/bash

set -e

sudo_docker="$([ -w '/var/run/docker.sock' ] || ! which sudo >/dev/null || echo 'sudo --preserve-env=DOCKER_BUILDKIT') docker"

while [ "$($sudo_docker ps -aq)" ]; do
    $sudo_docker rm $($sudo_docker ps -aq)
done

while [ "$($sudo_docker volume ls -q)" ]; do
    $sudo_docker volume rm $($sudo_docker volume ls -q)
done

while [ "$($sudo_docker system prune -f | tee /dev/stderr | sed -n '/./p' | tail -n1 | sed -n 's/^[[:space:]]*Total reclaimed space:[[:space:]]*\([0-9\.]*\).*/\1>0/p' | bc -l)" -gt 0 ]; do :; done

