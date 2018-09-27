#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1"

Invoke-Expression $($(cmd /c "`"${Env:ProgramFiles(x86)}/Microsoft Visual Studio/2017/Enterprise/VC/Auxiliary/Build/vcvarsall.bat`" x64 & set") -Match '^.+=' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
${Env:Path}="${Env:ProgramFiles}/NASM;${Env:Path}"

# TODO: Install NASM and ActivePerl automatically.
#       Current latest release (please install them manually now):
#           https://www.nasm.us/pub/nasm/releasebuilds/2.13.03/win64/nasm-2.13.03-installer-x64.exe
#           https://downloads.activestate.com/ActivePerl/releases/5.26.1.2601/ActivePerl-5.26.1.2601-MSWin32-x64-404865.exe

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/openssl/openssl.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "\\?\$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='OpenSSL_' + $($($($(git ls-remote --tags "$repo") -match '.*refs/tags/OpenSSL_[0-9\._]*$' -replace '.*refs/tags/OpenSSL_','' -replace '_','.' | sort {[Version]$_})[-1]) -replace '\.','_')
git clone --depth 1 --single-branch --recursive -j100 -b "$latest_ver" "$repo"
pushd "$root"

${Env:__CNF_CFLAGS}="${Env:__CNF_CFLAGS} /GL /MP /guard:cf"
${Env:__CNF_LDFLAGS}="${Env:__CNF_LDFLAGS} /INCREMENTAL:NO /LTCG:incremental /guard:cf"
perl Configure shared zlib VC-WIN64A --release --with-zlib-include="C:/PROGRA~1/zlib/include" --with-zlib-lib="C:/PROGRA~1/zlib/lib/zlib.lib"
nmake
nmake test

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/OpenSSL"
nmake install
Get-ChildItem "${Env:ProgramFiles}/OpenSSL" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
rm -Force -Recurse "\\?\$root"
popd
