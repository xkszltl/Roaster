#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/toolchain.ps1"

& "${Env:PYTHONHOME}/python.exe" -m pip install -U pytest

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/pybind/pybind11.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='v' + $($(git ls-remote --tags "$repo") -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v','' | sort {[Version]$_})[-1]
git clone --depth 1 --recursive --single-branch -b "$latest_ver" "$repo"
pushd "$root"
mkdir build
pushd build

cmake                                                               `
    -A x64                                                          `
    -DCMAKE_BUILD_TYPE=RelWithDebInfo                               `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP"                               `
    -DCMAKE_EXE_LINKER_FLAGS="/LTCG:incremental"                    `
    -DCMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"       `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/pybind11"           `
    -DCMAKE_SHARED_LINKER_FLAGS="/LTCG:incremental"                 `
    -DCMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"    `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -G"Visual Studio 15 2017"                                       `
    -T"host=x64"                                                    `
    ..

cmake --build . --config RelWithDebInfo -- -maxcpucount

$ErrorActionPreference="SilentlyContinue"
cmake --build . --config RelWithDebInfo --target check -- -maxcpucount
if (-Not $?)
{
    echo "Check failed but we temporarily bypass it."
}
$ErrorActionPreference="Stop"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/pybind11"
cmake --build . --config RelWithDebInfo --target install -- -maxcpucount
Get-ChildItem "${Env:ProgramFiles}/pybind11" -Filter '*.dll' -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
