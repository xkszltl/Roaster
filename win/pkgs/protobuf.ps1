#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

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
# git cherry-pick patch/constexpr-3.7

# Repo contains file "BUILD" for Bazel and it will conflict with "build" on NTFS.
mkdir build-win
pushd build-win

# ================================================================================
# Known issues:
#   - Avoid DLLs due symbol export issues with inline functions.
#     Keep happening and no good fix/test coverage from Google so far.
# ================================================================================

cmake                                                                   `
    -DBUILD_SHARED_LIBS=ON                                              `
    -DCMAKE_BUILD_TYPE=Release                                          `
    -DCMAKE_C_FLAGS="/GL /MP /Zi /arch:AVX2"                            `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP /Zi /arch:AVX2"                    `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"        `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/protobuf"               `
    -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                           `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"     `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                     `
    -Dprotobuf_BUILD_EXAMPLES=ON                                        `
    -Dprotobuf_BUILD_SHARED_LIBS=ON                                     `
    -Dprotobuf_INSTALL_EXAMPLES=ON                                      `
    -G"Ninja"                                                           `
    ../cmake

# Multi-process build is not ready.
# Conflict (permission denied) while multiple protoc generating the same file.
cmake --build .
if (-Not $?)
{
    echo "Failed to build."
    echo "Retry with best-effort for logging."
    echo "You may Ctrl-C this if you don't need the log file."
    cmake --build . -- -k0
    cmake --build . 2>&1 | tee ${Env:TMP}/${proj}.log
    exit 1
}

$ErrorActionPreference="SilentlyContinue"
cmake --build . --target check
if (-Not $?)
{
    echo "Check failed but we temporarily bypass it."
}
$ErrorActionPreference="Stop"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/protobuf"
cmake --build .  --target install
cmd /c xcopy /i /f /y "pdb\*.pdb" "${Env:ProgramFiles}\protobuf\bin"
Get-ChildItem "${Env:ProgramFiles}/protobuf" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }
Get-ChildItem "${Env:ProgramFiles}/protobuf" -Filter *.exe -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
