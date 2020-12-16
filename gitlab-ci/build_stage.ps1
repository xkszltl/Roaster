Param(
    [Parameter(Mandatory = $True)]
    [string] $stage,

    [Parameter(Mandatory = $True)]
    [string] $scratch
)

$ErrorActionPreference="Stop"

cd $PSScriptRoot/../win

${Env:SCRATCH} = $scratch
mkdir "${Env:SCRATCH}"

foreach ($pkg in $stage.Split(","))
{
    if ($pkg -ne "vsbuildtools")
    {
        . "pkgs/env/toolchain.ps1"
    }
    
    Write-Host "Install $pkg"
    
    $path = "pkgs/$pkg.ps1"
    if ($(Test-Path $path -ErrorAction SilentlyContinue))
    {
        & "${PSHOME}/powershell.exe" $path
        if (-Not $?)
        {
            Write-Host "[Error] Failed to install `"$pkg`""
            exit 1
        }
    }
    else
    {
        Write-Host "[Error] Script `"$path`" not found."
        exit 1
    }
}

# Post cleanup
rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:SCRATCH}"

Write-Host "Completed."
