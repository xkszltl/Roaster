#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:SCRATCH}
$repo="${Env:GIT_MIRROR}/Kitware/CMake.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:SCRATCH}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    exit 1
}

$latest_ver = 'v' + $($(git ls-remote --tags "$repo") -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v','' | sort {[Version]$_})[-1]

$cmake_url = "${Env:GIT_MIRROR_GITHUB}/Kitware/CMake/releases/download/$latest_ver"
$cmake_name = "cmake-$($latest_ver -replace '^v','')-windows-x86_x64.msi"
if (-not $(Test-Path "$cmake_name"))
{
    $uri = "$cmake_url/$cmake_name"
    Write-Host "Downloading `"$uri`""
    if ($(Test-Path "${Env:ProgramFiles}/CURL/bin/curl.exe" -ErrorAction SilentlyContinue))
    {
        & "${Env:ProgramFiles}/CURL/bin/curl.exe" -fkSL $uri -o "${cmake_name}.downloading"
    }
    else
    {
        Invoke-WebRequest -Uri $uri -OutFile "${cmake_name}.downloading"
    }
    mv -Force "${cmake_name}.downloading" ${cmake_name}
}

msiexec /i ${cmake_name} /norestart /passive ADD_CMAKE_TO_PATH=System | Out-Null
if (-Not $?)
{
    echo "Failed to install."
    exit 1
}

popd
