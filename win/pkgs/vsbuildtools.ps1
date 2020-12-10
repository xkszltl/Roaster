#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"

$vs_where = "${Env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
if (Test-Path $vs_where)
{
    $vs_home = & $vs_where -latest -products * -property installationPath
    if ($vs_home)
    {
        Write-Host "Found existing VS installation under `"$vs_home`". Skip installation."
        exit 0
    }
}

Invoke-WebRequest -Uri "https://aka.ms/vs/16/release/vs_buildtools.exe" -OutFile "${Env:SCRATCH}/vs_buildtools.exe"

$install_cmd = "`"${Env:SCRATCH}/vs_buildtools.exe`" "                      `
    + "--nocache "                                                          `
    + "--norestart "                                                        `
    + "--quiet "                                                            `
    + "--wait "                                                             `
    + "--add Microsoft.VisualStudio.Workload.VCTools;includeRecommended "   `
    + "--add Microsoft.VisualStudio.Component.Windows10SDK.16299 || exit /b %ERRORLEVEL%"

cmd /c $install_cmd

# Installation is still successful even if it returns non-zero error code 3010.
# The error code comes from the link below:
# https://docs.microsoft.com/en-us/visualstudio/install/build-tools-container?view=vs-2019
$error_code = $LASTEXITCODE
if ($error_code -ne 0 -or $error_code -ne 3010)
{
    Write-Error "Failed to install vs buildtools, exit code is $error_code."
    exit 1
}
