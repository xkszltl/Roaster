################################################################################
# Intel may ask you to register on their website before downloading libraries.
# Please follow their instructions and procedures.
#
# You agree to take full responsibility for using this script, and relief
# authors from any liability of not acquiring data in the normal way.
################################################################################

#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

$intel_url = "http://registrationcenter-download.intel.com/akdlm/irc_nas/tec"
$DownloadDir = Join-Path "$Env:TMP" Intel
New-Item -Path $DownloadDir -ItemType Directory -ErrorAction SilentlyContinue

# Note: update files and URI suffixes as new version are released.
$components = [System.Tuple]::Create("w_daal_2020.0.166.exe", "16224"),
              [System.Tuple]::Create("w_ipp_2020.0.166.exe", "16223"),
              [System.Tuple]::Create("w_mkl_2020.0.166.exe", "16222"),
              [System.Tuple]::Create("w_mpi_p_2019.6.166.exe", "16272"),
              [System.Tuple]::Create("w_tbb_2020.0.166.exe", "16271")

foreach ($i in 0..($components.Length - 1))
{
    $f = $components[$i].Item1
    $u = $components[$i].Item2
    if (-not $(Test-Path "${DownloadDir}/${f}"))
    {
        $uri = "$intel_url/$u/$f"
        Write-Host "Downloading $uri"
        & "${Env:ProgramFiles}/CURL/bin/curl.exe" -fkSL $uri -o "${DownloadDir}/${f}.downloading"
        mv -Force "${DownloadDir}/${f}.downloading" "${DownloadDir}/${f}"
    }
    Write-Host "Invoking $f to generate $($f.substring(0, $f.IndexOf(".exe"))) installation package"
    $InstallationDir = "$DownloadDir/$($f.substring(0, $f.IndexOf(".exe")))"
    & $DownloadDir/$f --silent --log "$DownloadDir/$f_installation_log.txt" --x --f $InstallationDir | Out-Null
    $setup = Join-Path $f.substring(0, $f.IndexOf(".exe")) install.exe
    Write-Host "Invoking $setup"
    dir $InstallationDir
    Write-Host "Make sure Visual Studio (including background processes) is not running or installer may hang."
    & $(Join-Path $DownloadDir $setup) install --output="$DownloadDir/$f_output_log.txt" --eula=accept | Out-Null
}

Get-ChildItem "${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/redist/intel64" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }
