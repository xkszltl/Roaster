#!/bin/bash

set -e

for cmd in date grep parallel ping rsync sed xargs; do
    if ! which "$cmd" >/dev/null; then
        printf '\033[31m[ERROR] Command "%s" not found.\033[0m\n' "$cmd" >&2
        exit 1
    fi
done

date

# ----------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------

[ "$DRY" ] || export DRY=false

DRY_RSYNC="$(! $DRY || printf '%s' '--dry-run')"

mkdir -p '/Latte/Mirrors/'
cd "$_"

repos='CTAN gnu'
repos="$(xargs -n1 <<< "$repos")"
[ "$#" -eq 0 ] || repos="$(grep $(sed 's/\([\\\/\.\-]\)/\\\1/g' <<< "$*" | sed 's/^/-e /') <<< "$repos")"

# ----------------------------------------------------------------
# CTAN/GNU Repository Mirroring
# ----------------------------------------------------------------

parallel --bar --line-buffer -j0 'bash -c '"'"'
    repo={}
    if false; then :
    elif '"$(sudo -nv 2>/dev/null && echo 'sudo ping -f' || echo 'ping')"' -qnc 10 mirrors.tuna.tsinghua.edu.cn -I 10.0.0.12; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete --address 10.0.0.12 "rsync://mirrors.tuna.tsinghua.edu.cn/{}/" "{}"
    elif '"$(sudo -nv 2>/dev/null && echo 'sudo ping -f' || echo 'ping')"' -qnc 10 rsync.mirrors.ustc.edu.cn    -I 10.0.0.12; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete --address 10.0.0.12 "rsync://rsync.mirrors.ustc.edu.cn/{}/"    "{}"
    elif '"$(sudo -nv 2>/dev/null && echo 'sudo ping -f' || echo 'ping')"' -qnc 10 mirrors.tuna.tsinghua.edu.cn -I 10.0.0.11; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete --address 10.0.0.11 "rsync://mirrors.tuna.tsinghua.edu.cn/{}/" "{}"
    elif '"$(sudo -nv 2>/dev/null && echo 'sudo ping -f' || echo 'ping')"' -qnc 10 rsync.mirrors.ustc.edu.cn    -I 10.0.0.11; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete --address 10.0.0.11 "rsync://rsync.mirrors.ustc.edu.cn/{}/"    "{}"
    elif '"$(sudo -nv 2>/dev/null && echo 'sudo ping -f' || echo 'ping')"' -qnc 10 mirrors.tuna.tsinghua.edu.cn; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete                     "rsync://mirrors.tuna.tsinghua.edu.cn/{}/" "{}"
    elif '"$(sudo -nv 2>/dev/null && echo 'sudo ping -f' || echo 'ping')"' -qnc 10 rsync.mirrors.ustc.edu.cn; then
        '"$DRY"' || rsync '"$DRY_RSYNC"' -aHSvPz --delete                     "rsync://rsync.mirrors.ustc.edu.cn/{}/"    "{}"
    else
       printf "\033[31m[ERROR] No mirror to try for \"%s\".\033[0m\n" "$repo" >&2
       exit 1
    fi
'"'" ::: $repos

printf '\033[32m[INFO] Repo "%s" mirrored.\033[0m\n' $repos >&2
