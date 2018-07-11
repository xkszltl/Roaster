#Requires -RunAsAdministrator

# ================================================================================
# PYTHONHOME
# ================================================================================
# Paths longer than 260 characters may resolve to some obscure errors. Let's avoid this by setting the appropriate registery value accordingly
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -Value 1 -Force

${Env:PYTHONHOME}="$(Get-Command -Name python | select -ExpandProperty Source | Split-Path -Parent)"
if (-not $(Test-Path ${Env:PYTHONHOME}))
{
    ${Env:PYTHONHOME} = which python | sed 's/\/c/c:/' | Get-Command | select -ExpandProperty Source | Split-Path -Parent
    if (-not $(Test-Path ${Env:PYTHONHOME}))
    {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $DownloadPath = "${Env:TEMP}/python-3.7.0-amd64.exe"
        Invoke-WebRequest -Uri https://www.python.org/ftp/python/3.7.0/python-3.7.0-amd64.exe -OutFile $DownloadPath
        & $DownloadPath /passive InstallAllUsers=1 PrependPath=1
        if ($(Test-Path ${Env:ProgramFiles}/Python37/python.exe))
        {
            ${Env:PYTHONHOME} = Join-Path ${Env:ProgramFiles} Python37
        }
        elseif ($(Test-Path ${Env:ProgramFiles(x86)}/Python37/python.exe))
        {
            ${Env:PYTHONHOME} = Join-Path ${Env:ProgramFiles(x86)} Python37
        }
        else
        {
           Write-Host Python Installation Failed. Please install manually: https://www.python.org/ftp/python/3.7.0/python-3.7.0-amd64.exe
        }
    }
}

# ================================================================================
# Summary
# ================================================================================

echo "================================================================================"
echo "| Detected Toolchains"
echo "--------------------------------------------------------------------------------"
echo "| Python Home:            ${Env:PYTHONHOME}"
echo "| Visual Studio Toolset:  ${Env:VCToolsInstallDir}"
echo "================================================================================"
