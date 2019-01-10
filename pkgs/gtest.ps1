#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1" | Out-Null
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/toolchain.ps1" | Out-Null

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/google/googletest.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='release-' + $($(git ls-remote --tags "$repo") -match '.*refs/tags/release-[0-9\.]*$' -replace '.*refs/tags/release-','' | sort {[Version]$_})[-1]
git clone --depth 1 --single-branch -b "$latest_ver" "$repo"
pushd "$root"
mkdir build
pushd build

# Silence hash_map/tr1 warning to avoid C2220.
# Silence all warnings (for C4244) because I'm tired.
# Turn off gmock_build_tests/gtest_build_tests due to error C1128 (VS 2017).

$gtest_silent_warning="/D_SILENCE_STDEXT_HASH_DEPRECATION_WARNINGS /D_SILENCE_TR1_NAMESPACE_DEPRECATION_WARNING /w"

# /Zi is hard-coded in googletest/cmake/internal_utils.cmake.
cmake                                                               `
    -DBUILD_SHARED_LIBS=ON                                          `
    -DCMAKE_BUILD_TYPE=Release                                      `
    -DCMAKE_C_FLAGS="/GL /MP"                                       `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP ${gtest_silent_warning}"       `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"    `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/googletest"         `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental" `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -Dgmock_build_tests=OFF                                         `
    -Dgtest_build_samples=ON                                        `
    -Dgtest_build_tests=OFF                                         `
    -G"Ninja"                                                       `
    ..

cmake --build .

$ErrorActionPreference="SilentlyContinue"
cmake --build . --target test
if (-Not $?)
{
    echo "Oops! Expect to pass all tests."
    exit 1
}
$ErrorActionPreference="Stop"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/googletest"
cmake --build . --target install
Get-ChildItem "${Env:ProgramFiles}/googletest" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

# Alias to default names in CMake.
cmd /c rmdir /S /Q "${Env:ProgramFiles}/gtest"
cmd /c rmdir /S /Q "${Env:ProgramFiles}/googletest-distribution"
cmd /c mklink /D "${Env:ProgramFiles}/gtest" "${Env:ProgramFiles}/googletest"
cmd /c mklink /D "${Env:ProgramFiles}/googletest-distribution" "${Env:ProgramFiles}/googletest"

popd
popd
rm -Force -Recurse "$root"
popd
