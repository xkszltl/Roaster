#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

$DownloadDir = "${Env:SCRATCH}/CUDA"
New-Item -Path $DownloadDir -Type Directory -ErrorAction SilentlyContinue
if (-not $(Test-Path $DownloadDir))
{
    Write-Host "Failed to create path $DownloadDir"
    Exit 1
}

$exe = "cuda_11.0.2_win10_network.exe"
if (-not $(Test-Path "${DownloadDir}/$exe"))
{
    Write-Host "Downloading CUDA installation files..."
    $wc = [System.Net.WebClient]::new()
    $wc.DownloadFile("https://developer.download.nvidia.com/compute/cuda/11.0.2/Prod/network_installers/${exe}", "${DownloadDir}/${exe}.downloading")
    mv -Force ${DownloadDir}/${exe}.downloading ${DownloadDir}/${exe}
}

Write-Host "Installing CUDA..."
& "${DownloadDir}/${exe}" -s | Out-Null
