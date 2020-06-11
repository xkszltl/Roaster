# Git installation script
# TODO: Automatically determine latest version of Git available for download. Until then, periodically check for newer version and update script
# TODO: Check that Git and Unix tools are added to CMD path for all users (see https://github.com/git-for-windows/build-extra/blob/master/installer/install.iss for options available for Windows Git installation).
#       After doing so, add this script to install.ps1

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

$DownloadDir = "${Env:SCRATCH}/Git"
New-Item -Path $DownloadDir -Type Directory -ErrorAction SilentlyContinue
if (-not $(Test-Path $DownloadDir))
{
    Write-Host "Failed to create path $DownloadDir"
    Exit 1
}

# Note: Periodically check for newer versions of Git and update accordingly
$exe = "Git-2.19.1.64-bit.exe"
if (-not $(Test-Path "$DownloadDir/$exe"))
{
    Write-Host "Downloading Git installation files..."
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    $wc = [System.Net.WebClient]::new()
    # TODO: Incorporate $exe variable in web client file download arguments
    $wc.DownloadFile("https://github.com/git-for-windows/git/releases/download/v2.19.1.windows.1/Git-2.19.1-64-bit.exe", "${Env:SCRATCH}/Git/Git-2.19.1.64-bit.exe")
}

Write-Host "Installing Git..."
& $(Join-Path $DownloadDir $exe) /SUPRESSMSGBOXES /LOG /CLOSEAPPLICATIONS /SAVEINF=$DownloadDir/GitInstallationSettings.inf /SILENT /Type=full | Out-Null

$Env:Path += ";$Env:ProgramFiles\Git\cmd" + ";${Env:ProgramFiles(x86)}\Git\cmd"