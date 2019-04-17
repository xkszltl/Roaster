#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/lmdb/lmdb.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver="LMDB_$($(git ls-remote --tags "$repo") -match '.*refs/tags/LMDB_[0-9\.]*$' -replace '.*refs/tags/LMDB_','' | sort {[Version]$_} | tail -n1)"
git clone --depth 1 --recursive --single-branch -b "$latest_ver" "$repo"
pushd "$root/libraries/liblmdb"

cmake                                   `
    -DBUILD_PACKAGING=ON                `
    -DBUILD_SHARED_LIBS=ON              `
    -DCMAKE_BUILD_TYPE=RelWithDebInfo   `
    -DCMAKE_C_FLAGS="/MP"               `
    -DCMAKE_CXX_FLAGS="/MP"             `
    -G"Visual Studio 15 2017 Win64"     `
    ..
cmake --build . --config RelWithDebInfo -- -maxcpucount
cmake --build . --config RelWithDebInfo --target package -- -maxcpucount
cmake --build . --config RelWithDebInfo --target install -- -maxcpucount

popd
rm -Force -Recurse "$root"
popd
