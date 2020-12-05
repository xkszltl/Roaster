#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:SCRATCH}
$repo="${Env:GIT_MIRROR}/google/snappy.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:SCRATCH}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver=$($(git ls-remote --tags "$repo") -match '.*refs/tags/[0-9\.]*$' -replace '.*refs/tags/','' | sort {[Version]$_})[-1]
$latest_ver="master"
git clone --depth 1 --single-branch -b "$latest_ver" "$repo"
pushd "$root"
mkdir build
pushd build

# Known issues:
#   - FindGTest does not cover our installation path.
#     https://gitlab.kitware.com/cmake/cmake/-/issues/21556
#   - Snappy uses GTest through cmake var, not target.
#     GTEST_LIBRARY_TYPE is only set for target property.
#     https://gitlab.kitware.com/cmake/cmake/-/blob/v3.19.1/Modules/FindGTest.cmake#L222-225
#   - Need additional /DNOMINMAX for std::max in unit tests.
#   - /GL doesn't work for unknown reason.
$gtest_dll="/DGTEST_LINKED_AS_SHARED_LIBRARY=1"
cmake                                                               `
    -DBUILD_SHARED_LIBS=ON                                          `
    -DCMAKE_BUILD_TYPE=Release                                      `
    -DCMAKE_C_FLAGS="/DNOMINMAX /MP /Zi ${gtest_dll}"               `
    -DCMAKE_CXX_FLAGS="/DNOMINMAX /EHsc /MP /Zi ${gtest_dll}"       `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"    `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/Snappy"             `
    -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                       `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental" `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -DGTEST_ROOT="${Env:ProgramFiles}/googletest-distribution"      `
    -DSNAPPY_REQUIRE_AVX2=ON                                        `
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

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/Snappy"
cmake --build . --target install
cmd /c xcopy /i /f /y "pdb\*.pdb" "${Env:ProgramFiles}\Snappy\bin"
Get-ChildItem "${Env:ProgramFiles}/Snappy" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
