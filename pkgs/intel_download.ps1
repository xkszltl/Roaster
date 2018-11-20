################################################################################
# Intel may ask you to register on their website before downloading libraries.
# Please follow their instructions and procedures.
#
# You agree to take full responsibility for using this script, and relief
# authors from any liability of not acquiring data in the normal way.
################################################################################
# TODO: Consider parallelizing downloads
#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"

$intel_url = "http://registrationcenter-download.intel.com/akdlm/irc_nas/tec"
$DownloadDir = Join-Path "$Env:TMP" Intel
New-Item -Path $DownloadDir -ItemType Directory -ErrorAction SilentlyContinue

$wc = [System.Net.Webclient]::new()
# Note: update files and URI suffixes as new version are released.
$components = [System.Tuple]::Create("w_daal_2019.1.144.exe", "14863"),
              [System.Tuple]::Create("w_ipp_2019.1.144.exe", "14889"),
              [System.Tuple]::Create("w_mkl_2019.1.144.exe", "14893"),
              [System.Tuple]::Create("w_mpi_p_2019.1.144.exe", "14881"),
              [System.Tuple]::Create("w_tbb_2019.2.144.exe", "14878")

foreach ($i in 0..($components.Length - 1))
{
    $f = $components[$i].Item1
    $u = $components[$i].Item2
    if (-not $(Test-Path "$DownloadDir/$f"))
    {
        $uri = "$intel_url/$u/$f"
        Write-Host "Downloading $uri"
        $wc.DownloadFile($uri, "$DownloadDir/$f")
        Sleep -Seconds 5 # delay to avoid race condition w/async file system updates
    }
    Write-Host "Invoking $f to generate $($f.substring(0, $f.IndexOf(".exe"))) installation package"
    $InstallationDir = "$DownloadDir/$($f.substring(0, $f.IndexOf(".exe")))"
    & $DownloadDir/$f --silent --log "$DownloadDir/$f_installation_log.txt" --x --f $InstallationDir | Out-Null
    $setup = Join-Path $f.substring(0, $f.IndexOf(".exe")) setup.exe
    Write-Host "Invoking $setup"
    dir $InstallationDir
    & $(Join-Path $DownloadDir $setup) install --output="$DownloadDir/$f_output_log.txt" --eula=accept | Out-Null
}
