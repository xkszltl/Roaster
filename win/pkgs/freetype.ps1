#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:SCRATCH}
$repo="https://git.savannah.gnu.org/git/freetype/freetype2.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:SCRATCH}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='VER-' + $($($(git ls-remote --tags "$repo") -match '.*refs/tags/VER\-[0-9\-]*$' -replace '.*refs/tags/VER\-','' -replace '\-','.' | sort {[Version]$_}) -replace '\.','-')[-1]
git clone --depth 1 --single-branch -b "$latest_ver" "$repo"
pushd "$root"
mkdir build
pushd build

cmake                                                               `
    -DBUILD_SHARED_LIBS=ON                                          `
    -DCMAKE_BUILD_TYPE=Release                                      `
    -DCMAKE_C_FLAGS="/GL /MP /Zi"                                   `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"    `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/freetype"           `
    -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                       `
    -DCMAKE_POLICY_DEFAULT_CMP0074=NEW                              `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental" `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -DFT_WITH_HARFBUZZ=ON                                           `
    -DFT_WITH_PNG=OFF                                               `
    -DFT_WITH_ZLIB=ON                                               `
    -DHarfBuzz_ROOT="${Env:ProgramFiles}/harfbuzz"                  `
    -G"Ninja"                                                       `
    ..

cmake --build .
if (-Not $?)
{
    echo "Failed to build."
    echo "Retry with best-effort for logging."
    echo "You may Ctrl-C this if you don't need the log file."
    cmake --build . -- -k0
    cmake --build . 2>&1 | tee ${Env:SCRATCH}/${proj}.log
    exit 1
}

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/freetype"
cmake --build . --target install
cmd /c xcopy /i /f /y "pdb\*.pdb" "${Env:ProgramFiles}\freetype\bin"
Get-ChildItem "${Env:ProgramFiles}/freetype" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
