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

$ver = "11.2.0"
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
if (${Env:VSCMD_VER} -ne $null)
{
    $vs_where = "${Env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
    $vs_home = & $vs_where -all -latest -products 'Microsoft.VisualStudio.Product.BuildTools' -property installationPath
    if ($vs_home)
    {
        $cuda_vsext_dir = "${Env:CUDA_PATH}/extras/visual_studio_integration/MSBuildExtensions"

        # See Table: CUDA Visual Studio .props locations from:
        # https://docs.nvidia.com/cuda/cuda-installation-guide-microsoft-windows/index.html
        #
        # For VS2019, the sample location is:
        # C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\MSBuild\Microsoft\VC\v160\BuildCustomizations
        ls "$vs_home/MSBuild/Microsoft/VC/*/BuildCustomizations" | % {
            $msbuild_custom_dir = $_.FullName

            Write-Host "Patching CUDA VS .props files:"
            Write-Host "  From: $cuda_vsext_dir"
            Write-Host "  To:   $msbuild_custom_dir"

            cp -Force $cuda_vsext_dir/* $msbuild_custom_dir    
        }
    }
}
