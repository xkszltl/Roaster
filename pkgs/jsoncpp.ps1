#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1" | Out-Null
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/toolchain.ps1" | Out-Null

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/open-source-parsers/jsoncpp.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver=$($(git ls-remote --tags "$repo") -match '.*refs/tags/[0-9\.]*$' -replace '.*refs/tags/','' | sort {[Version]$_})[-1]
git clone --depth 1 --single-branch -b "$latest_ver" "$repo"
pushd "$root"
mkdir build
pushd build

# - Please ignore warning C4273 since it is by design and safe.
#   dllexport in ".cc" will precedence over dllimport in ".h".
cmake                                                                   `
    -DBUILD_SHARED_LIBS=ON                                              `
    -DCMAKE_BUILD_TYPE=Release                                          `
    -DCMAKE_C_FLAGS="/GL /MP /Zi"                                       `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP /Zi"                               `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"        `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/jsoncpp"                `
    -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                           `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"     `
    -G"Ninja"                                                           `
    ..

cmake --build .
if (-Not $?)
{
    cmake --build . -- -k0
    cmake --build .
    exit 1
}

cmake --build . --target test
if (-Not $?)
{
    echo "Check failed."
    exit 1
}

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/jsoncpp"
cmake --build . --target install
cmd /c xcopy /i /f /y "pdb\*.pdb" "${Env:ProgramFiles}\jsoncpp\bin"
Get-ChildItem "${Env:ProgramFiles}/jsoncpp" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
