#!/bin/bash

# This one should be sourced.

set -e

pushd "$(dirname "$0")"
[ "$ROOT_DIR" ] || export ROOT_DIR="$(realpath ..)"
[ "$ROOT_DIR" ]
pushd "$ROOT_DIR"

echo '----------------------------------------------------------------'
echo '              Measure link quality to PIP mirrors               '
echo '----------------------------------------------------------------'

# - Update CN mirror list from CERNET.
#   https://mirrors.cernet.edu.cn/list/pypi
# - USTC mirror is currently redirected to Tuna or BFSU.
#   This affects probing quality.
#   https://github.com/ustclug/mirrorrequest/issues/213
TOPK="$(set -e +x >/dev/null
        printf '%s\n' "$TOPK" '2' | grep . | head -n1
    )"                                              \
. "$ROOT_DIR/geo/best-httping.sh"                   \
    https://pypi.org/simple                         \
    https://mirrors.163.com/pypi/simple             \
    https://mirrors.aliyun.com/pypi/simple          \
    https://mirrors.bfsu.edu.cn/pypi/web/simple     \
    https://mirrors.cernet.edu.cn/pypi/web/simple   \
    https://mirrors.cloud.tencent.com/pypi/simple   \
    https://mirrors.cqu.edu.cn/pypi/web/simple      \
    https://mirrors.jlu.edu.cn/pypi/web/simple      \
    https://mirror.nju.edu.cn/pypi/web/simple       \
    https://mirrors.pku.edu.cn/pypi/web/simple      \
    disabled-https://mirrors.ustc.edu.cn/pypi/web/simple    \
    https://mirrors.zju.edu.cn/pypi/web/simple      \
    https://pypi.tuna.tsinghua.edu.cn/simple
[ "$LINK_QUALITY" ]

printf '%s\n' "$LINK_QUALITY" | column -t | sed 's/^/| /'

echo '----------------------------------------------------------------'

[ "$PIP_INDEX_URL" ] || PIP_INDEX_URL="$(cut -d' ' -f2 <<< "$LINK_QUALITY" | head -n1)"
[ "$PIP_INDEX_URL" ]
LINK_QUALITY=''

popd
popd
