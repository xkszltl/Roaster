#!/bin/bash

set +x
set -e

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

cd "$(dirname "$0")"

for cmd in bc docker grep jq sed xargs; do
    if ! which "$cmd" >/dev/null; then
        printf '\033[31m[ERROR] Command "%s" not found.\033[0m\n' "$cmd" >&2
        exit 1
    fi
done

[ "$DOCKER_IMAGE" ] || DOCKER_IMAGE='roasterproject/centos'

if ! [ "$SUMMARIZING_IN_CONTAINER" ]; then
    printf '## New features\n\n'
    printf '%s ...\n\n' '-'

    printf '## Docker collection\n\n'
    for dist in CentOS Debian Ubuntu; do
        img="$(sed 's/\/\/*/\//' <<< "/$DOCKER_IMAGE" | sed 's/\/*$//' | sed 's/\/[^\/]*$//' | sed 's/^\///')/$(tr 'A-Z' 'a-z' <<< "$dist")"
        ! grep "^$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$img"):" <<< "$DOCKER_IMAGE:" >/dev/null || img="$DOCKER_IMAGE"
        printf '%s %s\n' '-' "$img"
    done
    printf '\n'

    printf '### Size\n\n'
    for dist in CentOS Debian Ubuntu; do
        img="$(sed 's/\/\/*/\//' <<< "/$DOCKER_IMAGE" | sed 's/\/*$//' | sed 's/\/[^\/]*$//' | sed 's/^\///')/$(tr 'A-Z' 'a-z' <<< "$dist")"
        ! grep "^$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$img"):" <<< "$dist:" || img="$dist"
        sudo docker images -q "$img" | grep '[^[:space:]]' >/dev/null || continue
        printf '%s %s: %s GiB, %s %% space efficiency\n'                    \
            '-'                                                             \
            "$dist"                                                         \
            "$(sudo docker inspect "$img"                                   \
                | jq -er '.[0].Size'                                        \
                | grep -v 'null'                                            \
                | xargs -r printf '(%s+2^29)/2^30\n'                        \
                | bc                                                        \
                | sed 's/^[[:space:]]*$/N\/A/'                              \
            )"                                                              \
            "$(DOCKER_IMAGE="$img" ./docker_efficiency.sh 2>&1 >/dev/null   \
                | grep '\[INFO\]'                                           \
                | sed -n 's/.* Space efficiency \([0-9\.]*\) *%.*/\1/p'     \
            )"
    done
    printf '\n'

    sudo docker run --entrypoint '' --rm -e SUMMARIZING_IN_CONTAINER=true -it -v "$(pwd):$(pwd):ro" "$DOCKER_IMAGE" "$(pwd)/$(basename "$0")"
else
    [ ! -e '/etc/os-release' ] || . <(sed 's/^\(..*\)/export DISTRO_\1/' '/etc/os-release')

    printf '## Highlights\n\n'
    printf '%s ...\n\n' '-'

    printf '## Roaster packages\n\n'
    printf '```\n'
    case "$DISTRO_ID" in
    "centos" | "fedora" | "rhel")
        rpm -qa 'roaster-*' | sort
        ;;
    "debian" | "linuxmint" | "ubuntu")
        dpkg -l 'roaster-*' | grep '^ii' | sed 's/  */ /g' | cut -d' ' -f2,3
        ;;
    esac
    printf '```\n\n'

    printf '### Nvidia packages\n\n'
    printf '```\n'
    case "$DISTRO_ID" in
    "centos" | "fedora" | "rhel")
        rpm -qa 'cuda*' | sort
        rpm -qa 'libcudnn*' | sort
        rpm -qa 'libnvinfer*' | sort
        rpm -qa 'libnccl*' | sort
        ;;
    "debian" | "linuxmint" | "ubuntu")
        dpkg -l {cuda,lib{cudnn,nvinfer,nccl}}'*' | grep '^ii' | sed 's/  */ /g' | cut -d' ' -f2,3
        ;;
    esac
    printf '```\n\n'
fi

trap - SIGTERM SIGINT EXIT
