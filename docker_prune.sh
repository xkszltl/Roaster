#!/bin/bash

set -e

while [ "$(docker ps -aq)" ]; do
    docker rm $(docker ps -aq)
done

while [ "$(docker volume ls -q)" ]; do
    docker volume rm $(docker volume ls -q)
done

while [ "$(sudo docker system prune -f | tee /dev/stderr | sed -n '/./p' | tail -n1 | sed -n 's/^[[:space:]]*Total reclaimed space:[[:space:]]*\([0-9\.]*\).*/\1>0/p' | bc -l)" -gt 0 ]; do :; done

