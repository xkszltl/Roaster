#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1"

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
cmake                                   `
    -DBUILD_GMOCK=ON                    `
    -DBUILD_GTEST=ON                    `
    -DBUILD_SHARED_LIBS=ON              `
    -DCMAKE_BUILD_TYPE=RelWithDebInfo   `
    -DCMAKE_C_FLAGS="/MP"               `
    -DCMAKE_CXX_FLAGS="/D_SILENCE_STDEXT_HASH_DEPRECATION_WARNINGS /D_SILENCE_TR1_NAMESPACE_DEPRECATION_WARNING /MP /w" `
    -DCMAKE_EXE_LINKER_FLAGS="/LTCG"    `
    -DCMAKE_SHARED_LINKER_FLAGS="/LTCG" `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG" `
    -Dgmock_build_tests=OFF             `
    -Dgtest_build_samples=ON            `
    -Dgtest_build_tests=OFF             `
    -G"Visual Studio 15 2017 Win64"     `
    ..

cmake --build . --config RelWithDebInfo -- -maxcpucount

cmake --build . --config RelWithDebInfo --target run_tests -- -maxcpucount

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/googletest-distribution"
cmake --build . --config RelWithDebInfo --target install -- -maxcpucount
Get-ChildItem "${Env:ProgramFiles}/googletest-distribution" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
