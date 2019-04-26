#!/bin/bash

set -e

sudo echo 'Permission granted.'

while [ "$(sudo docker ps -aq)" ]; do
    sudo docker rm $(sudo docker ps -aq)
done

while [ "$(sudo docker volume ls -q)" ]; do
    sudo docker volume rm $(sudo docker volume ls -q)
done

while [ "$(sudo docker system prune -f | tee /dev/stderr | sed -n '/./p' | tail -n1 | sed -n 's/^[[:space:]]*Total reclaimed space:[[:space:]]*\([0-9\.]*\).*/\1>0/p' | bc -l)" -gt 0 ]; do :; done

