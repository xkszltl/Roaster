#Requires -RunAsAdministrator

# ================================================================================
# PYTHONHOME
# ================================================================================
# Paths longer than 260 characters may resolve to some obscure errors. Let's avoid this by setting the appropriate registery value accordingly
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -Value 1 -Force

${Env:PYTHONHOME} = "$(Get-Command -Name python -ErrorAction SilentlyContinue | select -ExpandProperty Source | Split-Path -Parent)"

if (${Env:PYTHONHOME} -eq $null -or -not $(Test-Path ${Env:PYTHONHOME} -ErrorAction SilentlyContinue))
{
    ${Env:PYTHONHOME} = which python | sed 's/\/c/c:/' | Get-Command | select -ExpandProperty Source | Split-Path -Parent
    if (${Env:PYTHONHOME} -eq $null -or -not $(Test-Path ${Env:PYTHONHOME}))
    {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $DownloadPath = "${Env:TEMP}/python-3.7.1-amd64.exe"
        Write-Host "Downloading Python..."
        Invoke-WebRequest -Uri https://www.python.org/ftp/python/3.7.1/python-3.7.1-amd64.exe -OutFile $DownloadPath
        Write-Host "Installing Python..."
        & $DownloadPath /passive InstallAllUsers=1 PrependPath=1 | Out-Null
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
             Write-Host Python Installation Failed. Please install manually: https://www.python.org/ftp/python/3.7.1/python-3.7.1-amd64.exe
             Exit 1
        }
    }
    ${Env:PATH} = "${Env:PYTHONHOME};${Env:PATH}"
}

if (${Env:VSCMD_VER} -eq $null)
{
    Invoke-Expression $($(cmd /c "`"${Env:ProgramFiles(x86)}/Microsoft Visual Studio/2017/Enterprise/VC/Auxiliary/Build/vcvarsall.bat`" x64 & set") -Match '^.+=' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
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
