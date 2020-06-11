#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:SCRATCH}
$repo="${Env:GIT_MIRROR}/google/leveldb.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:SCRATCH}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver="v" + $($(git ls-remote --tags "$repo") -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v','' | sort {[Version]$_})[-1]
git clone --depth 1 --single-branch -b "$latest_ver" "$repo"
pushd "$root"
mkdir build
pushd build

cmake                                   `
    -DBUILD_SHARED_LIBS=ON				`
    -DCMAKE_BUILD_TYPE=RelWithDebInfo   `
    -DCMAKE_C_FLAGS="/MP"               `
    -DCMAKE_CXX_FLAGS="/MP"             `
    -G"Visual Studio 15 2017 Win64"     `
    ..
cmake --build . --config RelWithDebInfo -- -maxcpucount
cmake --build . --config RelWithDebInfo --target run_tests -- -maxcpucount
cmake --build . --config RelWithDebInfo --target install -- -maxcpucount

popd
popd
rm -Force -Recurse "$root"
popd
