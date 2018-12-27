#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1"

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/madler/zlib.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='v' + $($(git ls-remote --tags "$repo") -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v','' | sort {[Version]$_})[-1]
git clone --depth 1 --recursive --single-branch -b "$latest_ver" -j8 "$repo"
pushd "$root"

mkdir build
pushd build

# Currently (v1.2.11) there's a bug related to AMD64 flag.
cmake                                                               `
    -A x64                                                          `
    -DAMD64=OFF                                                     `
    -DCMAKE_BUILD_TYPE=RelWithDebInfo                               `
    -DCMAKE_C_FLAGS="/GL /MP /guard:cf"                             `
    -DCMAKE_EXE_LINKER_FLAGS="/LTCG:incremental /guard:cf"          `
    -DCMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"       `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/zlib"               `
    -DCMAKE_SHARED_LINKER_FLAGS="/LTCG:incremental /guard:cf"       `
    -DCMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"    `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -G"Visual Studio 15 2017"                                       `
    -T"host=x64"                                                    `
    ..

cmake --build . --config RelWithDebInfo -- -m
cmake --build . --config RelWithDebInfo --target run_tests -- -m

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/zlib"
cmake --build . --config RelWithDebInfo --target install -- -m
Get-ChildItem "${Env:ProgramFiles}/zlib" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
