#!/bin/bash

set +x

(
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
                    sed -i "s/$(sed 's/\([\/\.]\)/\\\1/g' <<< "$i" | tr '=' '/')/" .gitmodules
                done
                for i in $(sed -n 's/^\([[:alnum:]][^\/[:space:]]*\)\/[^\/[:space:]].*,.*/\1/p' "$ROOT_DIR/mirrors.sh"); do
                    # Case-insensitive with escape.
                    Ii="$(paste -d' '                   \
                            <(tr a-z A-Z <<< "$i" | sed 's/\(.\)/\1 /g' | xargs -n1)    \
                            <(tr A-Z a-z <<< "$i" | sed 's/\(.\)/\1 /g' | xargs -n1)    \
                        | sed 's/\(.\) \(.\)/\[\1\2\]/' \
                        | sed 's/^\[[^A-Za-z]/\[/'      \
                        | paste -sd' ' -                \
                        | sed 's/ //g'                  \
                        | sed 's/\([\/\.\-]\)/\\\1/g')"
                    sed -i "s/[^[:space:]]*:\/\/[^\/]*\(\/$Ii\/.*[^\/]\)[\/]*/$(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR")\1.git/" .gitmodules
                    sed -i "s/\($(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR")\/$Ii\/.*\.git\)\.git[[:space:]]*$/\1/" .gitmodules
                done
                # TODO:
                #     This is a temporary solution for sourceware.org mirroring.
                #     Should use config file instead ASAP.
                for i in $(sed -n 's/^\([[:alnum:]][^\/[:space:]]*\),.*/\1/p' "$ROOT_DIR/mirrors.sh"); do
                    sed -i "s/[^[:space:]]*:\/\/[^\/].*\(\/$i\.git\)[\/]*/$(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR")\/sourceware\1.git/" .gitmodules
                    sed -i "s/\($(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR")\/sourceware\/$i\.git\)\.git[[:space:]]*$/\1/" .gitmodules
                done
                # gRPC->bloaty->libFuzzer is hosted on googlesource.com, not always accessible.
                #   - https://github.com/grpc/grpc/issues/24926
                # Use a mirror on gitee for now.
                sed -i 's/https:\/\/.*\/chromium\/llvm\-project\/llvm\/lib\/Fuzzer/https:\/\/gitee\.com\/local-grpc\/Fuzzer\.git/' .gitmodules
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

            SUBMODULE_QUEUE="$(sed 's/;;*/;/g' <<< "$SUBMODULE_QUEUE;$(git config --file .gitmodules --name-only --get-regexp path | cut -d'.' -f2- | sed 's/\.[^\.]*$//' | xargs readlink -e | paste -sd';' -)" | sed 's/^;*//' | sed 's/;*$//')"
        fi

        popd
    done
)

