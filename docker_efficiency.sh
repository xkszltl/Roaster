#!/bin/bash

set -e

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

cd "$(dirname "$0")"

for cmd in bc docker grep jq sed xargs; do
    ! which "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "%s".\033[0m\n' "$cmd" >&2
    exit 1
done

sudo_docker="$([ -w '/var/run/docker.sock' ] || ! which sudo >/dev/null || echo 'sudo --preserve-env=DOCKER_BUILDKIT') docker"

[ "$DOCKER_IMAGE" ] || DOCKER_IMAGE="$@"
[ "$DOCKER_IMAGE" ] || DOCKER_IMAGE='roasterproject/centos roasterproject/debian roasterproject/ubuntu'
DOCKER_IMAGE="$(sed 's/[[:space:]][[:space:]]*/ /g' <<< "$DOCKER_IMAGE" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
[ "$DOCKER_IMAGE" ]

[ "$DIR" ] || DIR='/'

if grep '[[:space:]]' <<< "$DOCKER_IMAGE" >/dev/null; then
    xargs -n1 "./$(basename "$0")" <<< "$DOCKER_IMAGE" | column -t
    exit 0
fi

image_size="$(set -e;
    $sudo_docker inspect "$DOCKER_IMAGE" \
    | jq -er '.[].Size'
)"

image_size="$(set -e;
    $sudo_docker run --rm -i --entrypoint '' "$DOCKER_IMAGE" bash -c "du --exclude=/{dev,proc} -B1 -cs '$DIR'"  \
    | tail -n1                                                                                                  \
    | cut -f1
)"

layer_size="$(set -e;
    $sudo_docker inspect "$DOCKER_IMAGE"                                             \
    | jq -er '.[].GraphDriver.Data.LowerDir + ":" + .[].GraphDriver.Data.UpperDir'  \
    | grep -v null                                                                  \
    | xargs -d: -n1                                                                 \
    | grep '.'                                                                      \
    | sed 's/$/'"$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$DIR")"'/'                    \
    | paste -s -                                                                    \
    | sudo xargs -L1 du -B1 -cs 2>/dev/null                                         \
    | tail -n1                                                                      \
    | cut -f1
)"

[ "$image_size" -gt 0 ]
[ "$layer_size" -gt 0 ]

bc -l <<< "100.0 * $image_size / $layer_size"   \
| xargs -rI{} printf '\033[36m[INFO] Space efficiency %.1f%% for "%s" in "%s".\033[0m\n' {} "$DIR" "$DOCKER_IMAGE" >&2

trap - SIGTERM SIGINT EXIT
