#!/bin/bash

set -e

date

# ----------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------

[ "$DRY" ] || export DRY=false

DRY_RSYNC="$(! $DRY || printf '%s' '--dry-run')"

mkdir -p '/Latte/Mirrors/'
cd "$_"

# ----------------------------------------------------------------
# CTAN/GNU Repository Mirroring
# ----------------------------------------------------------------

parallel --bar --line-buffer -j0 'bash -c '"'"'
    [ "'"$#"'" -eq 0 ] || grep -i {} <<< "'"$@"'" || exit 0
    if false; then :
    elif ping -nfc 10 mirrors.tuna.tsinghua.edu.cn -I 10.0.0.12; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete --address 10.0.0.12 "rsync://mirrors.tuna.tsinghua.edu.cn/{}/" "{}"
    elif ping -nfc 10 rsync.mirrors.ustc.edu.cn -I 10.0.0.12; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete --address 10.0.0.12 "rsync://rsync.mirrors.ustc.edu.cn/{}/" "{}"
    elif ping -nfc 10 mirrors.tuna.tsinghua.edu.cn -I 10.0.0.11; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete --address 10.0.0.11 "rsync://mirrors.tuna.tsinghua.edu.cn/{}/" "{}"
    elif ping -nfc 10 rsync.mirrors.ustc.edu.cn -I 10.0.0.11; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete --address 10.0.0.11 "rsync://rsync.mirrors.ustc.edu.cn/{}/" "$u"
    elif ping -nfc 10 mirrors.tuna.tsinghua.edu.cn; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete "rsync://mirrors.tuna.tsinghua.edu.cn/{}/" "{}"
    elif ping -nfc 10 rsync.mirrors.ustc.edu.cn then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete"rsync://rsync.mirrors.ustc.edu.cn/{}/" "{}"
    else
       printf "\033[31m[ERROR] No mirror to try for \"%s\".\033[0m\n" "$i" >&2
       exit 1
    fi
'"'" ::: CTAN gnu
