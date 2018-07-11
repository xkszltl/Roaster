#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1"

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/boostorg/boost.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root=Join-Path ${Env:TMP} $proj

if (Test-Path $root)
{
    cmd /c rmdir /S /Q $root
    if (Test-Path $root)
    {
        echo "Failed to remove $root"
        Exit 1
    }
}

$latest_ver='boost-' + $($(git ls-remote --tags $repo) -match '.*refs/tags/boost-[0-9\.]*$' -replace '.*refs/tags/boost-','' | sort {[Version]$_})[-1]
git clone --depth 1 --recursive --single-branch -b $latest_ver -j50 $repo

pushd $root
./bootstrap
./b2 -j"$Env:NUMBER_OF_PROCESSORS" link=shared --threading=multi address-model=64 runtime-link=shared

$InstallationPath = Join-Path $Env:ProgramFiles 'boost'
if (Test-Path $InstallationPath)
{
    cmd /c rmdir /S /Q $InstallationPath
    if (Test-Path $InstallationPath)
    {
        echo "Failed to remove $InstallationPath"
        Exit 1
    }
}

./b2 --prefix=$InstallationPath -j"$Env:NUMBER_OF_PROCESSORS" link=shared --threading=multi address-model=64 runtime-link=shared install
Get-ChildItem $InstallationPath -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }
popd

cmd /c rmdir /S /Q $root
popd
