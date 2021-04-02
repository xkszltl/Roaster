#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"

$vs_where = "${Env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
if (Test-Path $vs_where)
{
    $vs_home = & $vs_where -all -latest -products * -property installationPath
    if ($vs_home)
    {
        Write-Host "Found existing VS installation under `"$vs_home`". Skip installation."
        exit 0
    }
}

Invoke-WebRequest -Uri "https://aka.ms/vs/16/release/vs_buildtools.exe" -OutFile "${Env:SCRATCH}/vs_buildtools.exe"

& "${Env:SCRATCH}/vs_buildtools.exe"                                    `
    --nocache                                                           `
    --norestart                                                         `
    --wait                                                              `
    --quiet                                                             `
    --add "Microsoft.VisualStudio.Workload.VCTools;includeRecommended"  `
    --add "Microsoft.VisualStudio.Component.Windows10SDK.16299" | Out-Null

$error_code = $LASTEXITCODE
if ($error_code -ne 0)
{
    Write-Error "Failed to install vs buildtools, exit code is $error_code."
    exit 1
}
