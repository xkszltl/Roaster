#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
# . "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/c-ares/c-ares.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    Write-Output "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='cares-' + $($(git ls-remote --tags "$repo") -match '.*refs/tags/cares-[0-9_]*$' -replace '.*refs/tags/cares-','' -replace '_', '.' | Sort-Object {[Version]$_})[-1] -replace '\.','_'
git clone --depth 1 --recursive --single-branch -b "$latest_ver" "$repo"
pushd "$root"

mkdir build
pushd build

cmake                                                               `
    -DCARES_SHARED=ON                                               `
    -DCARES_STATIC=ON                                               `
    -DCARES_BUILD_TESTS=OFF                                         `
    -DCARES_BUILD_TOOLS=ON                                          `
    -DCMAKE_BUILD_TYPE=Release                                      `
    -DCMAKE_C_FLAGS="/DWIN32 /GL /MP /Zi"                           `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"    `
    -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                       `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental" `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}\c-ares"             `
    -G"Ninja"                                                       `
    ..

cmake --build .
if (-Not $?)
{
    Write-Output "Failed to build."
    Write-Output "Retry with best-effort for logging."
    Write-Output "You may Ctrl-C this if you don't need the log file."
    cmake --build . -- -k0
    cmake --build . 2>&1 | Tee-Object ${Env:TMP}/${proj}.log
    exit 1
}

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/c-ares"
cmake --build . --target install
cmd /c xcopy /i /f /y "pdb\*.pdb" "${Env:ProgramFiles}\c-ares\bin"
Get-ChildItem "${Env:ProgramFiles}/c-ares" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd