#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/opencv/opencv.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver="$($(git ls-remote --tags "$repo") -match '.*refs/tags/[0-9\.]*$' -replace '.*refs/tags/','' | sort {[Version]$_} | tail -n1)"
git clone --depth 1 --recursive --single-branch -b "$latest_ver" -j8 "$repo"
pushd "$root"

mkdir build
pushd build

# Copy TBB's environment variables from ".bat" file to PowerShell.
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/tbb/bin/tbbvars.bat`" intel64 vs2015 & env") -Match '^TBB(_|ROOT)' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)

# - Only "Release" and "Debug" are supported.
#   Use "BUILD_WITH_DEBUG_INFO" for "RelWithDebInfo".
# - Use VS 2015 for CUDA 9.1 compatibility.
# - MKL_WITH_TBB may not work with latest TBB directory structure.
cmake                                                                   `
    -DBUILD_SHARED_LIBS=ON                                              `
    -DBUILD_WITH_DEBUG_INFO=ON                                          `
    -DBUILD_WITH_STATIC_CRT=OFF                                         `
    -DCMAKE_BUILD_TYPE=Release                                          `
    -DCMAKE_C_FLAGS="/MP"                                               `
    -DCMAKE_CXX_FLAGS="/MP"                                             `
    -DCMAKE_EXE_LINKER_FLAGS="/LTCG"                                    `
    -DCMAKE_SHARED_LINKER_FLAGS="/LTCG"                                 `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG"                                 `
    -DCUDA_SEPARABLE_COMPILATION=OFF                                    `
    -DEIGEN_INCLUDE_PATH="${Env:ProgramFiles}/Eigen3/include/eigen3"    `
    -DENABLE_LTO=ON                                                     `
    -DINSTALL_CREATE_DISTRIB=OFF                                        `
    -DOPENCV_ENABLE_NONFREE=OFF                                         `
    -DPROTOBUF_UPDATE_FILES=ON                                          `
    -DWITH_CUDA=OFF                                                     `
    -DWITH_MKL=ON                                                       `
    -DWITH_OPENGL=ON                                                    `
    -DWITH_OPENMP=ON                                                    `
    -DWITH_TBB=ON                                                       `
    -G"Visual Studio 14 2015 Win64"                                     `
    ..

cmake --build . --config Release -- -maxcpucount

$ErrorActionPreference="SilentlyContinue"
cmake --build . --config Release --target run_tests -- -maxcpucount
if (-Not $?)
{
    echo "Check failed but we temporarily bypass it."
}
$ErrorActionPreference="Stop"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/opencv"
cmake --build . --config Release --target install -- -maxcpucount
Get-ChildItem "${Env:ProgramFiles}/opencv" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
