#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1"

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/boostorg/boost.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver="boost-$($(git ls-remote --tags "$repo") -match '.*refs/tags/boost-[0-9\.]*$' -replace '.*refs/tags/boost-','' | sort {[Version]$_} | tail -n1)"
git clone --depth 1 --recursive --single-branch -b "$latest_ver" -j8 "$repo"
pushd "$root"

./bootstrap

./b2 --prefix="${Env:ProgramFiles}/boost"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/boost"
./b2 --prefix="${Env:ProgramFiles}/boost" install
Get-ChildItem "${Env:ProgramFiles}/boost" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
rm -Force -Recurse "$root"
popd
