#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

${Env:Path}="${Env:ProgramFiles}/NASM;${Env:Path}"

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/openssl/openssl.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "\\?\$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='OpenSSL_' + $($($($(git ls-remote --tags "$repo") -match '.*refs/tags/OpenSSL_[0-9\._]*$' -replace '.*refs/tags/OpenSSL_','' -replace '_','.' | sort {[Version]$_})[-1]) -replace '\.','_')
git clone --depth 1 --single-branch --recursive -j100 -b "$latest_ver" "$repo"
pushd "$root"

${Env:__CNF_CFLAGS}="${Env:__CNF_CFLAGS} /GL /MP /guard:cf"
${Env:__CNF_LDFLAGS}="${Env:__CNF_LDFLAGS} /INCREMENTAL:NO /LTCG:incremental /guard:cf"
perl Configure shared zlib VC-WIN64A --release --with-zlib-include="C:/PROGRA~1/zlib/include" --with-zlib-lib="C:/PROGRA~1/zlib/lib/zlib.lib"

nmake
if (-Not $?)
{
    echo "Failed to build."
    exit 1
}

# nmake test

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/OpenSSL"
nmake install
Get-ChildItem "${Env:ProgramFiles}/OpenSSL" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
rm -Force -Recurse "\\?\$root"
popd
