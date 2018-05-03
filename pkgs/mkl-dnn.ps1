#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/toolchain.ps1"

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/intel/mkl-dnn.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver="v$($(git ls-remote --tags "$repo") -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v','' | sort {[Version]$_} | tail -n1)"
# Windows support is not ready in v0.13.
$latest_ver="master"
git clone --depth 1 --recursive --single-branch -b "$latest_ver" "$repo"
pushd "$root"

Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 vs2015 & env") -Match '^MKLROOT' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)

mkdir build
pushd build

cmake                                   `
    -DCMAKE_BUILD_TYPE=Release          `
    -DCMAKE_C_FLAGS="/MP /Zi"           `
    -DCMAKE_CXX_FLAGS="/EHsc /MP /Zi"   `
    -G"Visual Studio 15 2017 Win64"     `
    -T"host=x64"                        `
    ..

cmake --build . --config Release -- -maxcpucount

cmake --build . --config Release --target run_tests -- -maxcpucount

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/Intel(R) MKL-DNN"
cmake --build . --config Release --target install -- -maxcpucount

popd
popd
rm -Force -Recurse "$root"
popd
