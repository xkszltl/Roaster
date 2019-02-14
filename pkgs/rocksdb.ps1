#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/facebook/rocksdb.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='v' + $($(git ls-remote --tags "$repo") -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v','' | sort {[Version]$_})[-1]
# Need "rocksdb-shared.lib" patch after v5.17.2
$latest_ver='master'
git clone --single-branch -b "$latest_ver" "$repo"

pushd "$root"

git remote add patch https://github.com/xkszltl/rocksdb.git
git fetch patch

mkdir build
pushd build

${Env:GFLAGS_INCLUDE} = "${Env:ProgramFiles}/GFlags/include/"
${Env:GFLAGS_LIB_DEBUG} = "${Env:ProgramFiles}/GFlags/lib/gflags.lib"
${Env:GFLAGS_LIB_RELEASE} = "${Env:ProgramFiles}/GFlags/lib/gflags.lib"
${Env:SNAPPY_INCLUDE} = "${Env:ProgramFiles}/Snappy/include/"
${Env:SNAPPY_LIB_DEBUG} = "${Env:ProgramFiles}/Snappy/lib/snappy.lib"
${Env:SNAPPY_LIB_RELEASE} = "${Env:ProgramFiles}/Snappy/lib/snappy.lib"
${Env:ZLIB_INCLUDE} = "${Env:ProgramFiles}/zlib/include/"
${Env:ZLIB_LIB_DEBUG} = "${Env:ProgramFiles}/zlib/lib/zlib.lib"
${Env:ZLIB_LIB_RELEASE} = "${Env:ProgramFiles}/zlib/lib/zlib.lib"

# Known issues:
#   - Tests are not supported in CMake Release build.
#   - /Zi hard-coded.
cmake                                                               `
    -DCMAKE_BUILD_TYPE=Release                                      `
    -DCMAKE_C_FLAGS="/GL /MP"                                       `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP"                               `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"    `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/rocksdb"            `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental" `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -DFAIL_ON_WARNINGS=OFF                                          `
    -DROCKSDB_INSTALL_ON_WINDOWS=ON                                 `
    -DWITH_GFLAGS=ON                                                `
    -DWITH_SNAPPY=ON                                                `
    -DWITH_TESTS=OFF                                                `
    -DWITH_XPRESS=ON                                                `
    -DWITH_ZLIB=ON                                                  `
    -G"Ninja"                                                       `
    ..

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
# cmake --build . --target test
# if (-Not $?)
# {
#     echo "Oops! Expect to pass all tests."
#     exit 1
# }
$ErrorActionPreference="Stop"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/rocksdb"
cmake --build . --target install
Get-ChildItem "${Env:ProgramFiles}/rocksdb" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
# rm -Force -Recurse "$root"
popd
