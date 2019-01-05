#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1"

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
git clone --depth 1 --single-branch -b "$latest_ver" "$repo"
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

# Tests are not supported in CMake Release build.
cmake                                                               `
    -A x64                                                          `
    -DCMAKE_BUILD_TYPE=RelWithDebInfo                               `
    -DCMAKE_C_FLAGS="/GL /MP"                                       `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP"                               `
    -DCMAKE_EXE_LINKER_FLAGS="/LTCG:incremental"                    `
    -DCMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"       `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/rocksdb"            `
    -DCMAKE_SHARED_LINKER_FLAGS="/LTCG:incremental"                 `
    -DCMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"    `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -DFAIL_ON_WARNINGS=OFF                                          `
    -DROCKSDB_INSTALL_ON_WINDOWS=ON                                 `
    -DWITH_GFLAGS=ON                                                `
    -DWITH_SNAPPY=ON                                                `
    -DWITH_TESTS=OFF                                                `
    -DWITH_XPRESS=ON                                                `
    -DWITH_ZLIB=ON                                                  `
    -G"Visual Studio 15 2017"                                       `
    -T"host=x64"                                                    `
    ..

cmake --build . --config RelWithDebInfo -- -maxcpucount
# cmake --build . --config RelWithDebInfo --target run_tests -- -maxcpucount

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/rocksdb"
cmake --build . --config RelWithDebInfo --target install -- -maxcpucount
Get-ChildItem "${Env:ProgramFiles}/rocksdb" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
# rm -Force -Recurse "$root"
popd
