#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

Push-Location ${Env:TMP}

$repo="${Env:GIT_MIRROR}/grpc/grpc.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

Remove-Item -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    Write-Output "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='v' + $($(git ls-remote --tags "$repo") -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v','' | Sort-Object {[Version]$_})[-1]
git clone --depth 1 --single-branch -b "$latest_ver" "$repo"
Push-Location "$root"

mkdir build-win
Push-Location build-win

cmake                                                               `
    -DBUILD_SHARED_LIBS=OFF                                         `
    -DCMAKE_BUILD_TYPE=Release                                      `
    -DgRPC_BUILD_TESTS=OFF                                          `
    -DgRPC_BENCHMARK_PROVIDER=package                               `
    -DgRPC_CARES_PROVIDER=package                                   `
    -DgRPC_GFLAGS_PROVIDER=package                                  `
    -DgRPC_INSTALL=ON                                               `
    -DgRPC_PROTOBUF_PROVIDER=package                                `
    -DgRPC_PROTOBUF_PACKAGE_TYPE=CONFIG                             `
    -DgRPC_SSL_PROVIDER=package                                     `
    -DgRPC_ZLIB_PROVIDER=package                                    `
    -DCMAKE_C_FLAGS="/GL /MP /Zi /DPROTOBUF_USE_DLLS"               `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP /Zi /DPROTOBUF_USE_DLLS"       `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"    `
    -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                       `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental" `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -G"Ninja"                                                       `
    ..

cmake --build .
if (-Not $?)
{
    Write-Output "Failed to build."
    Write-Output "Retry with best-effort for logging."
    Write-Output "You may Ctrl-C this if you don't need the log file."
    cmake --build . -- -k0
    cmake --build . 2>&1 | Tee-Object ${Env:TMP}/${proj}.log
    exit 1
}

Remove-Item -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/grpc"
cmake --build . --target install
cmd /c xcopy /i /f /y "pdb\*.pdb" "${Env:ProgramFiles}\grpc\bin"
Get-ChildItem "${Env:ProgramFiles}/grpc" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

Pop-Location
Pop-Location
Remove-Item -Force -Recurse "$root"
Pop-Location