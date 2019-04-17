#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/intel/mkl-dnn.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver="v" + $($(git ls-remote --tags "$repo") -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v','' | sort {[Version]$_})[-1]
git clone --depth 1 --recursive --single-branch -b "$latest_ver" "$repo"
pushd "$root"

scripts/prepare_mkl.bat
if (-Not $?)
{
    echo "Failed to get MKLML."
    exit 1
}

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/mklml"

pushd external
if (Get-Command -Name unzip -ErrorAction SilentlyContinue)
{
    unzip -ou "mklml_win_*.zip" -d "mklml.d"
}
else
{
    Expand-Archive "mklml_win_*.zip" "mklml.d"
}
mv -force mklml.d/mklml_win_* mklml
xcopy /e /i /f /y "mklml\*" "${Env:ProgramFiles}\mklml"
popd

Get-ChildItem "${Env:ProgramFiles}/mklml" -Filter 'mklml.dll' -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
rm -Force -Recurse "$root"
popd
