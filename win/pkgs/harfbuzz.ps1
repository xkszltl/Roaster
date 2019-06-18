#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/harfbuzz/harfbuzz.git"
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

${Env:FREETYPE_DIR}="${Env:ProgramFiles}/freetype"
cmake                                                               `
    -DBUILD_SHARED_LIBS=ON                                          `
    -DCMAKE_BUILD_TYPE=Release                                      `
    -DCMAKE_C_FLAGS="/GL /MP /Zi"                                   `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP /Zi"                           `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"    `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/harfbuzz"           `
    -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                       `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental" `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                 `
    -DHB_HAVE_DIRECTWRITE=ON                                        `
    -DHB_HAVE_FREETYPE=ON                                           `
    -DHB_HAVE_UNISCRIBE=ON                                          `
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
cmake --build . --target test
if (-Not $?)
{
    echo "Check failed but we temporarily bypass it."
}
$ErrorActionPreference="Stop"

# rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/harfbuzz"
cmake --build . --target install
cmd /c xcopy /i /f /y "pdb\*.pdb" "${Env:ProgramFiles}\harfbuzz\bin"
Get-ChildItem "${Env:ProgramFiles}/harfbuzz" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
