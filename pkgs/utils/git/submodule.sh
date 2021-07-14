#!/bin/bash


set +x

(
    if [ ! "$ROOT_DIR" ]; then
        echo '$ROOT_DIR is not defined.'
        echo 'Running in standalone mode.'
        export ROOT_DIR="$(realpath -e "$(dirname "$0")")"
        until [ -x "$ROOT_DIR/setup.sh" ] && [ -d "$ROOT_DIR/pkgs" ]; do export ROOT_DIR=$(realpath -e "$ROOT_DIR/.."); done
        [ "_$ROOT_DIR" != "_$(readlink -f "$ROOT_DIR/..")" ]
        echo 'Set $ROOT_DIR to "'"$ROOT_DIR"'".'
    fi

    [ "$GIT_MIRROR" ] || . "$ROOT_DIR/pkgs/env/mirror.sh"

    case "$DISTRO_ID" in
    'centos' | 'fedora' | 'rhel')
        set +e
        . scl_source enable rh-git218 || exit 1
        set -e
        ;;
    esac

    set -e

    SUBMODULE_QUEUE='.'

    while [ "$SUBMODULE_QUEUE" ]; do
        pushd "$(cut -d';' -f1 <<< "$SUBMODULE_QUEUE;")"
        echo "Recurse into submodule \"$_\"."
        SUBMODULE_QUEUE="$(cut -d';' -f2- <<< "$SUBMODULE_QUEUE;" | sed 's/;*$//')"

        if [ -e .gitmodules ]; then
            if [ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ]; then
                # export HTTP_PROXY=proxy.codingcafe.org:8118
                [ "$HTTP_PROXY" ] && export HTTPS_PROXY="$HTTP_PROXY"
                [ "$HTTP_PROXY" ] && export http_proxy="$HTTP_PROXY"
                [ "$HTTPS_PROXY" ] && export https_proxy="$HTTPS_PROXY"

                for i in 01org/mkl-dnn=intel/mkl-dnn google/upb=protocolbuffers/upb lyft/protoc-gen-validate=envoyproxy/protoc-gen-validate philsquared/Catch=catchorg/Catch2; do
                    sed -i "s/$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$i" | tr '=' '/')/" .gitmodules
                done
                for i in $("$ROOT_DIR/mirror-list.sh" | sed 's/ /,/g'); do
                    # Case-insensitive with escape.
                    Ii="$(paste -d' '                   \
                            <(cut -d',' -f3 <<< "$i,," | tr 'a-z' 'A-Z' | sed 's/\(.\)/\1 /g' | xargs -n1)  \
                            <(cut -d',' -f3 <<< "$i,," | tr 'A-Z' 'a-z' | sed 's/\(.\)/\1 /g' | xargs -n1)  \
                        | sed 's/\(.\) \(.\)/\[\1\2\]/' \
                        | sed 's/^\[[^A-Za-z]/\[/'      \
                        | paste -sd' ' -                \
                        | sed 's/ //g'                  \
                        | sed 's/\([\\\/\.\-]\)/\\\1/g')"
                    grep "$Ii" .gitmodules >/dev/null || continue
                    set -x
                    origin_esc="$(cut -d',' -f1 <<< "$i" | sed 's/\/*$/\//' | sed 's/\([\\\/\.\-]\)/\\\1/g')"
                    mirror_esc="$(sed 's/\([^:]\/\)\/*/\1/g' <<< "$GIT_MIRROR/$(cut -d, -f2 <<< "$i,")/$(cut -d, -f3 <<< "$i,,").git" | sed 's/\([\\\/\.\-]\)/\\\1/g')"
                    sed -i 's/'"$origin_esc"'\('"$Ii"'\)\.git[\/]*[[:space:]]*$/'"$mirror_esc"'/' .gitmodules
                    sed -i 's/'"$origin_esc"'\('"$Ii"'\)[\/]*[[:space:]]*$/'"$mirror_esc"'/'      .gitmodules
                    sed -i 's/\('"$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$GIT_MIRROR")"'\/.*\.git\)\.git[[:space:]]*$/\1/' .gitmodules
                    set +x
                done

                # TODO:
                #     This is a temporary solution for sourceware.org mirroring.
                #     Should use config file instead ASAP.
                # for i in $(sed -n 's/^\([[:alnum:]][^\/[:space:]]*\),.*/\1/p' "$ROOT_DIR/mirrors.sh"); do
                #     sed -i "s/[^[:space:]]*:\/\/[^\/].*\(\/$i\.git\)[\/]*/$(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$GIT_MIRROR")\/sourceware\1.git/" .gitmodules
                #     sed -i "s/\($(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$GIT_MIRROR")\/sourceware\/$i\.git\)\.git[[:space:]]*$/\1/" .gitmodules
                # done

                # gRPC->bloaty->libFuzzer is hosted on googlesource.com, not always accessible.
                #   - https://github.com/grpc/grpc/issues/24926
                # Use a mirror on gitee for now.
                sed -i 's/https:\/\/.*\/chromium\/llvm\-project\/llvm\/lib\/Fuzzer/https:\/\/gitee\.com\/local-grpc\/Fuzzer\.git/' .gitmodules

                git --no-pager diff .gitmodules
            fi

            git submodule init
            for i in $(seq 10 -1 0); do
                # Exponential back-off.
                # GitHub may stall with too many large submodules.
                [ "$(git submodule init | wc -l)" -gt 10 ] && timeout -k 10s  5m git submodule update -j 100 && break
                [ "$(git submodule init | wc -l)" -gt  1 ] && timeout -k 10s 30m git submodule update -j  10 && break
                [ "$(git submodule init | wc -l)" -gt  0 ] &&                    git submodule update -j   1 && break
                git submodule update && break
                sleep 1
                echo "Retrying... $i time(s) left."
            done

            SUBMODULE_QUEUE="$(sed 's/;;*/;/g' <<< "$SUBMODULE_QUEUE;$(git config --file .gitmodules --name-only --get-regexp path | cut -d'.' -f2- | sed 's/\.[^\.]*$//' | xargs realpath -e | paste -sd';' -)" | sed 's/^;*//' | sed 's/;*$//')"
        fi

        popd
    done
)

