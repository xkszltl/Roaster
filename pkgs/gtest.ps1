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

$gtest_silent_warning="/D_SILENCE_STDEXT_HASH_DEPRECATION_WARNINGS /D_SILENCE_TR1_NAMESPACE_DEPRECATION_WARNING /w"

cmake                                                               `
    -DBUILD_GMOCK=ON                                                `
    -DBUILD_GTEST=ON                                                `
    -DBUILD_SHARED_LIBS=ON                                          `
    -DCMAKE_BUILD_TYPE=Release                                      `
    -DCMAKE_C_FLAGS="/GL /MP /Z7"                                   `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP /Z7 ${gtest_silent_warning}"   `
    -DCMAKE_EXE_LINKER_FLAGS="/LTCG:incremental"                    `
    -DCMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"       `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/googletest"         `
    -DCMAKE_SHARED_LINKER_FLAGS="/LTCG:incremental"                 `
    -DCMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"    `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -Dgmock_build_tests=OFF                                         `
    -Dgtest_build_samples=ON                                        `
    -Dgtest_build_tests=OFF                                         `
    -G"Visual Studio 15 2017 Win64"                                 `
    -T"host=x64"                                                    `
    ..

cmake --build . --config Release -- -maxcpucount

cmake --build . --config Release --target run_tests -- -maxcpucount

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/googletest"
cmake --build . --config Release --target install -- -maxcpucount
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
