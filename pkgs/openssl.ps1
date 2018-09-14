#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1"

Invoke-Expression $($(cmd /c "`"${Env:ProgramFiles(x86)}/Microsoft Visual Studio/2017/Enterprise/VC/Auxiliary/Build/vcvarsall.bat`" x64 & set") -Match '^.+=' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
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

perl Configure shared no-zlib VC-WIN64A
nmake
nmake test

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/OpenSSL"
nmake install
Get-ChildItem "${Env:ProgramFiles}/OpenSSL" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
rm -Force -Recurse "\\?\$root"
popd
