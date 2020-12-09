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

$ver = "11.1.1"
$exe = "cuda_${ver}_win10_network.exe"
if (-not $(Test-Path "${DownloadDir}/${exe}"))
{
    Write-Host "Downloading CUDA installation files..."
    $wc = [System.Net.WebClient]::new()
    $wc.DownloadFile("https://developer.download.nvidia.com/compute/cuda/${ver}/network_installers/${exe}", "${DownloadDir}/${exe}.downloading")
    mv -Force ${DownloadDir}/${exe}.downloading ${DownloadDir}/${exe}
}

Write-Host "Installing CUDA..."
& "${DownloadDir}/${exe}" -s | Out-Null

${Env:CUDA_PATH}=[System.Environment]::GetEnvironmentVariable("CUDA_PATH","Machine")

# CUDA MSBuild integration is not working for VS BuildTools.
# Manually install CUDA Build Customizations files into MSBuild customization folder.
#
# See Table 4. CUDA Visual Studio .props locations from
# https://docs.nvidia.com/cuda/cuda-installation-guide-microsoft-windows/index.html
$vs_where = "${Env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
if (Test-Path $vs_where)
{
    $vs_home = & $vs_where -latest -products 'Microsoft.VisualStudio.Product.BuildTools' -property installationPath
    if ($vs_home)
    {
        Write-Host "Found existing VS installtaion under `"$vs_home`". Skip installation."

        $cuda_vsext_dir = "${Env:CUDA_PATH}/extras/visual_studio_integration/MSBuildExtensions"
        $msbuild_custom_dir = "$vs_home/MSBuild/Microsoft/VC/v160/BuildCustomizations"

        Write-Host "Patching CUDA VS .props files:"
        Write-Host "  From: $cuda_vsext_dir"
        Write-Host "  To:   $msbuild_custom_dir"
        Copy-Item $cuda_vsext_dir/* $msbuild_custom_dir
    }
}
