#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1" | Out-Null

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/eigenteam/eigen-git-mirror.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

# ================================================================================
# Known issues:
# - Release 3.3.4 has compatibility issue with CUDA 9.1, ignored.
# - Master has ambiguity issue about __hadd in CUDA 9.1, patched.
#   >> [ __hadd(int, int) for int avg ] vs. [ __hadd(__half, __half) for fp16 ].
# ================================================================================
$latest_ver="$($(git ls-remote --tags "$repo") -match '.*refs/tags/[0-9\.]*$' -replace '.*refs/tags/','' | sort {[Version]$_})[-1]"
# Compatibility issues between CUDA 9.1 and Eigen 3.3.4
$latest_ver="master"
git clone --depth 1 --single-branch -b "$latest_ver" "$repo"
pushd "$root"

pushd "Eigen/src/Core/arch/GPU"
echo "Patch for `"${latest_ver}`" about __hadd."
$(cat Half.h) -Replace '(\s__hadd\(\s*)(\w*)(,\s*)(\w*)(\s*\))','${1}static_cast<__half>(${2})${3}static_cast<__half>(${4})${5}' > .Half.h
mv -Force .Half.h Half.h
popd

mkdir build
pushd build

cmake                                   `
    -DCMAKE_BUILD_TYPE=RelWithDebInfo   `
    -DCMAKE_C_FLAGS="/MP"               `
    -DCMAKE_CXX_FLAGS="/MP"             `
    -DEIGEN_TEST_CUDA=ON                `
    -DEIGEN_TEST_CXX11=ON               `
    -G"Visual Studio 15 2017 Win64"     `
    ..

cmake --build . --config RelWithDebInfo -- -maxcpucount

cmake --build . --config RelWithDebInfo --target blas -- -maxcpucount

# cmake --build . --config RelWithDebInfo --target check -- -maxcpucount

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/Eigen3"
cmake --build . --config RelWithDebInfo --target install -- -maxcpucount

popd
popd
rm -Force -Recurse "$root"
popd
