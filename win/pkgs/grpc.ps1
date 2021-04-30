#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:SCRATCH}
$repo="${Env:GIT_MIRROR}/grpc/grpc.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:SCRATCH}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    Write-Host "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='v' + $($(git ls-remote --tags "$repo") -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v','' | sort {[Version]$_})[-1]

git clone --depth 1 --recursive --single-branch -b "$latest_ver" "$repo"
pushd "$root"
mkdir build-win
pushd build-win

# ================================================================================
# Known issues:
#   - Set <PackageName>_ROOT or c-ares may be found under Windows git.
# ================================================================================

cmake                                                               `
    -DBUILD_SHARED_LIBS=OFF                                         `
    -DCMAKE_BUILD_TYPE=Release                                      `
    -DCMAKE_C_FLAGS="/MP /Zi"                                       `
    -DCMAKE_CXX_FLAGS="/EHsc /MP /Zi"                               `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK"                      `
    -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                       `
    -DCMAKE_POLICY_DEFAULT_CMP0074=NEW                              `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK"                   `
    -Dc-ares_ROOT="${Env:ProgramFiles}/c-ares;${Env:ProgramFiles(x86)}/c-ares"  `
    -DgRPC_BENCHMARK_PROVIDER=package                               `
    -DgRPC_BUILD_TESTS=OFF                                          `
    -DgRPC_CARES_PROVIDER=package                                   `
    -DgRPC_INSTALL=ON                                               `
    -DgRPC_PROTOBUF_PACKAGE_TYPE=CONFIG                             `
    -DgRPC_PROTOBUF_PROVIDER=package                                `
    -DgRPC_SSL_PROVIDER=package                                     `
    -DgRPC_ZLIB_PROVIDER=package                                    `
    -G"Ninja"                                                       `
    ..

cmake --build .
if (-Not $?)
{
    Write-Host "Failed to build."
    Write-Host "Retry with best-effort for logging."
    Write-Host "You may Ctrl-C this if you don't need the log file."
    cmake --build . -- -k0
    cmake --build . 2>&1 | Tee-Object ${Env:SCRATCH}/${proj}.log
    exit 1
}

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles(x86)}/grpc"
cmake --build . --target install
cmd /c xcopy /i /f /y "pdb\*.pdb" "${Env:ProgramFiles(x86)}\grpc\bin"
Get-ChildItem "${Env:ProgramFiles(x86)}/grpc" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd

# Known issue:
#   - abseil header is not installed via grpc
#     https://github.com/grpc/grpc/issues/25949
mkdir third_party/abseil-cpp/build
pushd third_party/abseil-cpp/build

cmake                                               `
    -DCMAKE_INSTALL_PREFIX="${Env:SCRATCH}/abseil"  `
    -G"Ninja"                                       `
    ..

cmake --build . --config Release --target install
if (-Not $?)
{
    Write-Host "Failed to build abseil."
    exit 1
}

Copy-Item -Recurse -Force "${Env:SCRATCH}/abseil/include" "${Env:ProgramFiles(x86)}/grpc"

popd

# Remove-Item cannot remove symlink.
cmd /c rmdir /S /Q spm-core-include
cmd /c rmdir /S /Q spm-cpp-include
popd
rm -Force -Recurse "$root"
popd
