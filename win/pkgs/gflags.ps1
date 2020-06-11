#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:SCRATCH}
$repo="${Env:GIT_MIRROR}/gflags/gflags.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:SCRATCH}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='v' + $($(git ls-remote --tags "$repo") -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v','' | sort {[Version]$_})[-1]
git clone --depth 1 --recursive --single-branch -b "$latest_ver" "$repo"
pushd "$root"
mkdir build-win
pushd build-win

cmake                                                               `
    -DBUILD_PACKAGING=ON                                            `
    -DBUILD_SHARED_LIBS=ON                                          `
    -DBUILD_TESTING=ON                                              `
    -DCMAKE_BUILD_TYPE=Release                                      `
    -DCMAKE_C_FLAGS="/GL /MP /Zi"                                   `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP /Zi"                           `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"    `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/gflags"             `
    -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                       `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental" `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -G"Ninja"                                                       `
    ..

cmake --build .
if (-Not $?)
{
    echo "Failed to build."
    echo "Retry with best-effort for logging."
    echo "You may Ctrl-C this if you don't need the log file."
    cmake --build . -- -k0
    cmake --build . 2>&1 | tee ${Env:SCRATCH}/${proj}.log
    exit 1
}

$ErrorActionPreference="SilentlyContinue"
cmake --build . --target test
if (-Not $?)
{
    echo "Oops! Expect to pass all tests."
    exit 1
}
$ErrorActionPreference="Stop"

cmake --build . --target package

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/gflags"
cmake --build . --target install
cmd /c xcopy /i /f /y "pdb\*.pdb" "${Env:ProgramFiles}\gflags\bin"
Get-ChildItem "${Env:ProgramFiles}/gflags" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
