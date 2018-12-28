#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1" | Out-Null

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/google/glog.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='v' + $($(git ls-remote --tags "$repo") -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v','' | sort {[Version]$_})[-1]
git clone --depth 1 --single-branch -b "$latest_ver" "$repo"
pushd "$root"
mkdir build-win
pushd build-win

# - Please ignore warning C4273 since it is by design and safe.
#   dllexport in ".cc" will precedence over dllimport in ".h".
cmake                                                               `
    -A x64                                                          `
    -DBUILD_SHARED_LIBS=ON 				                            `
    -DCMAKE_BUILD_TYPE=RelWithDebInfo                               `
    -DCMAKE_C_FLAGS="/GL /MP"                                       `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP"                               `
    -DCMAKE_EXE_LINKER_FLAGS="/LTCG:incremental"                    `
    -DCMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"       `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/google-glog"        `
    -DCMAKE_SHARED_LINKER_FLAGS="/LTCG:incremental"                 `
    -DCMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"    `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -G"Visual Studio 15 2017"                                       `
    -T"host=x64"                                                    `
    ..

cmake --build . --config RelWithDebInfo -- -maxcpucount

# cmake --build . --config RelWithDebInfo --target run_tests -- -maxcpucount

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/google-glog"
cmake --build . --config RelWithDebInfo --target install -- -maxcpucount
Get-ChildItem "${Env:ProgramFiles}/google-glog" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
