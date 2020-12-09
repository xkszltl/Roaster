#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"

$vs_where = "${Env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
if (Test-Path $vs_where)
{
    $vs_home = & $vs_where -latest -products * -property installationPath
    if ($vs_home)
    {
        Write-Host "Found existing VS installtaion under `"$vs_home`". Skip installation."
        exit 0
    }
}

Invoke-WebRequest -Uri https://aka.ms/vs/16/release/vs_buildtools.exe -OutFile "${Env:SCRATCH}/vs_buildtools.exe"

$install_cmd = "`"${Env:SCRATCH}/vs_buildtools.exe`" --quiet --wait --norestart --nocache " `
    + "--add Microsoft.VisualStudio.Workload.VCTools;includeRecommended "                   `
    + "--add Microsoft.VisualStudio.Component.Windows10SDK.16299 "                          `
    + "--installPath C:\BuildTools || exit /b %ERRORLEVEL%"
cmd /c $install_cmd

if ($LASTEXITCODE -ne 0 -or $LASTEXITCODE -ne 3003)
{
    Write-Error "Failed to install vs buildtools, exit code is $LASTEXITCODE."
    exit 1
}
