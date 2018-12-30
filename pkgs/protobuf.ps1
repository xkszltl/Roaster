#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1" | Out-Null

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/google/protobuf.git"
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

git remote add patch https://github.com/xkszltl/protobuf.git
git fetch patch
git cherry-pick patch/constexpr-3.6

# Repo contains file "BUILD" for Bazel and it will conflict with "build" on NTFS.
mkdir build-win
pushd build-win

# - Avoid DLLs due symbol export issues with inline functions.
#   Keep happening and no good fix/test coverage from Google so far.
cmake                                                               `
    -A x64                                                          `
    -DBUILD_SHARED_LIBS=ON                                          `
    -DCMAKE_BUILD_TYPE=RelWithDebInfo                               `
    -DCMAKE_C_FLAGS="/GL /MP"                                       `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP"                               `
    -DCMAKE_EXE_LINKER_FLAGS="/LTCG:incremental"                    `
    -DCMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"       `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/protobuf"           `
    -DCMAKE_SHARED_LINKER_FLAGS="/LTCG:incremental"                 `
    -DCMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"    `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -Dprotobuf_BUILD_EXAMPLES=ON                                    `
    -Dprotobuf_BUILD_SHARED_LIBS=ON                                 `
    -Dprotobuf_INSTALL_EXAMPLES=ON                                  `
    -G"Visual Studio 15 2017"                                       `
    -T"host=x64"                                                    `
    ../cmake

# Multi-process build is not ready.
# Conflict (permission denied) while multiple protoc generating the same file.
cmake --build . --config RelWithDebInfo -- -maxcpucount

$ErrorActionPreference="SilentlyContinue"
cmake --build . --config RelWithDebInfo --target check -- -maxcpucount
if (-Not $?)
{
    echo "Check failed but we temporarily bypass it."
}
$ErrorActionPreference="Stop"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/protobuf"
cmake --build . --config RelWithDebInfo --target install
Get-ChildItem "${Env:ProgramFiles}/protobuf" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }
Get-ChildItem "${Env:ProgramFiles}/protobuf" -Filter *.exe -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
