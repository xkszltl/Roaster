#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:SCRATCH}
$repo="${Env:GIT_MIRROR}/curl/curl.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root= Join-Path "${Env:SCRATCH}" "$proj"

cmd /c rmdir /S /Q "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='curl-' + $($($($(git ls-remote --tags "$repo") -match '.*refs/tags/curl-[0-9\._]*$' -replace '.*refs/tags/curl-','') -replace '_','.' | sort {[Version]$_})[-1] -replace '\.','_')
git clone --depth 1 --single-branch -b "$latest_ver" "$repo"
pushd "$root"

# ================================================================================
# Build
# ================================================================================

mkdir build
pushd build

cmake                                                               `
    -A x64                                                          `
    -DBUILD_SHARED_LIBS=ON                                          `
    -DCMAKE_C_FLAGS="/GL /MP"                                       `
    -DCMAKE_EXE_LINKER_FLAGS="/LTCG:incremental"                    `
    -DCMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"       `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/CURL"               `
    -DCMAKE_SHARED_LINKER_FLAGS="/LTCG:incremental"                 `
    -DCMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"    `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -DCMAKE_USE_WINSSL=ON                                           `
    -DCMAKE_USE_OPENSSL=ON                                          `
    -DCURL_CA_FALLBACK=ON                                           `
    -DENABLE_ARES=OFF                                               `
    -G"Visual Studio 16 2019"                                       `
    -T"host=x64"                                                    `
    ..

cmake --build . --config RelWithDebInfo -- -maxcpucount
cmake --build . --config RelWithDebInfo --target run_tests -- -maxcpucount

cmd /c rmdir /S /Q "${Env:ProgramFiles}/CURL"
cmake --build . --config RelWithDebInfo --target install -- -maxcpucount
Get-ChildItem "${Env:ProgramFiles}/CURL" -Filter '*.dll' -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }
try
{
    Get-ChildItem "${Env:ProgramFiles}/CURL" -Filter *.exe -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }
}
catch
{
    Write-Host "Already have curl executable installed. Skipped."
}

popd
popd
rm -Force -Recurse "$root"
popd
