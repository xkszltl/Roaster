#Requires -RunAsAdministrator

# Paths longer than 260 characters may resolve to some obscure errors. Let's avoid this by setting the appropriate registery value accordingly
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -Value 1 -Force

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ================================================================================
# Perl
# ================================================================================

${Env:PERL_HOME} = "$(Get-Command -Name perl -ErrorAction SilentlyContinue | select -ExpandProperty Source | Split-Path -Parent)"

if (${Env:PERL_HOME} -eq $null -or -not $(Test-Path ${Env:PERL_HOME}/perl.exe -ErrorAction SilentlyContinue))
{
    ${Env:PERL_HOME} = Join-Path C: Perl64 bin
}

if (${Env:PERL_HOME} -eq $null -or -not $(Test-Path ${Env:PERL_HOME}/perl.exe -ErrorAction SilentlyContinue))
{
    $perl_ver="5.26.1.2601-MSWin32-x64-404865"
    $DownloadURL = "https://downloads.activestate.com/ActivePerl/releases/" + $(${perl_ver} -replace '-.*','') + "/ActivePerl-${perl_ver}.exe"
    $DownloadPath = "${Env:TMP}/ActivePerl-${perl_ver}.exe"
    Write-Host "Downloading ActivePerl..."
    Invoke-WebRequest -Uri $DownloadURL -OutFile $DownloadPath
    Write-Host "Installing ActivePerl..."
    & $DownloadPath /passive InstallAllUsers=1 PrependPath=1 | Out-Null
    if ($(Test-Path C:/Perl64/bin/perl.exe -ErrorAction SilentlyContinue))
    {
        ${Env:PERL_HOME} = Join-Path C: Perl64 bin
        Write-Host "ActivePerl installed successfully."
    }
    else
    {
        Write-Host "ActivePerl installation Failed. Please install manually: ${DownloadURL}"
        Exit 1
    }
}

${Env:PATH} = "${Env:PERL_HOME};${Env:PATH}"

# ================================================================================
# NASM
# ================================================================================

${Env:NASM_HOME} = "$(Get-Command -Name nasm -ErrorAction SilentlyContinue | select -ExpandProperty Source | Split-Path -Parent)"

if (${Env:NASM_HOME} -eq $null -or -not $(Test-Path ${Env:NASM_HOME}/nasm.exe -ErrorAction SilentlyContinue))
{
    ${Env:NASM_HOME} = Join-Path ${Env:ProgramFiles} NASM
}

if (${Env:NASM_HOME} -eq $null -or -not $(Test-Path ${Env:NASM_HOME}/nasm.exe -ErrorAction SilentlyContinue))
{
    # NASM 2.14.0{1,2} are banned by Windows Defender.
    $nasm_ver="2.14"
    $DownloadURL = "https://www.nasm.us/pub/nasm/releasebuilds/${nasm_ver}/win64/nasm-${nasm_ver}-installer-x64.exe"
    $DownloadPath = "${Env:TMP}/nasm-${nasm_ver}-installer-x64.exe"
    Write-Host "Downloading NASM..."
    Invoke-WebRequest -Uri $DownloadURL -OutFile $DownloadPath
    Write-Host "Installing NASM..."
    & $DownloadPath /S | Out-Null
    if ($(Test-Path "${Env:ProgramFiles}/NASM/nasm.exe" -ErrorAction SilentlyContinue))
    {
        ${Env:NASM_HOME} = Join-Path ${Env:ProgramFiles} NASM
        Write-Host "NASM installed successfully."
    }
    else
    {
        Write-Host "NASM installation Failed. Please install manually: ${DownloadURL}"
        Exit 1
    }
}

${Env:PATH} = "${Env:NASM_HOME};${Env:PATH}"

# ================================================================================
# Python
# ================================================================================

${Env:PYTHONHOME} = "$(Get-Command -Name python -ErrorAction SilentlyContinue | select -ExpandProperty Source | Split-Path -Parent)"

if (${Env:PYTHONHOME} -eq $null -or -not $(Test-Path ${Env:PYTHONHOME}/python.exe -ErrorAction SilentlyContinue))
{
    ${Env:PYTHONHOME} = Join-Path ${Env:ProgramFiles} Python37
}

if (${Env:PYTHONHOME} -eq $null -or -not $(Test-Path ${Env:PYTHONHOME}/python.exe -ErrorAction SilentlyContinue))
{
    $py_ver="3.7.2"
    $DownloadURL = "https://www.python.org/ftp/python/${py_ver}/python-${py_ver}-amd64.exe"
    $DownloadPath = "${Env:TMP}/python-${py_ver}-amd64.exe"
    Write-Host "Downloading Python..."
    Invoke-WebRequest -Uri $DownloadURL -OutFile $DownloadPath
    Write-Host "Installing Python..."
    & $DownloadPath /passive InstallAllUsers=1 PrependPath=1 | Out-Null
    if ($(Test-Path ${Env:ProgramFiles}/Python37/python.exe -ErrorAction SilentlyContinue))
    {
        ${Env:PYTHONHOME} = Join-Path ${Env:ProgramFiles} Python37
        Write-Host "Python installed successfully."
    }
    else
    {
        Write-Host "Python installation Failed. Please install manually: ${DownloadURL}"
        Exit 1
    }
}

${Env:PATH} = "${Env:PYTHONHOME};${Env:PATH}"

# ================================================================================
# Update pip
# ================================================================================

Write-Host "Updating pip..."

& "${Env:PYTHONHOME}/python.exe" -m pip install -U setuptools | Out-Null
& "${Env:PYTHONHOME}/python.exe" -m pip install -U pip | Out-Null
& "${Env:PYTHONHOME}/python.exe" -m pip install -U wheel | Out-Null
& "${Env:PYTHONHOME}/python.exe" -m pip install -U future | Out-Null

# ================================================================================
# Ninja
# ================================================================================

${Env:NINJA_HOME} = "$(Get-Command -Name ninja -ErrorAction SilentlyContinue | select -ExpandProperty Source | Split-Path -Parent)"

if (${Env:NINJA_HOME} -eq $null -or -not $(Test-Path ${Env:NINJA_HOME}/ninja.exe -ErrorAction SilentlyContinue))
{
    ${Env:NINJA_HOME} = Join-Path ${Env:ProgramFiles} Ninja
}

if (${Env:NINJA_HOME} -eq $null -or -not $(Test-Path ${Env:NINJA_HOME}/ninja.exe -ErrorAction SilentlyContinue))
{
    $ninja_ver="1.8.2"
    $DownloadURL = "https://github.com/ninja-build/ninja/releases/download/v${ninja_ver}/ninja-win.zip"
    $DownloadPath = "${Env:TMP}/ninja-win.zip"
    Write-Host "Downloading Ninja..."
    Invoke-WebRequest -Uri $DownloadURL -OutFile $DownloadPath
    Expand-Archive ${DownloadPath} ${Env:ProgramFiles}/Ninja
    if ($(Test-Path ${Env:ProgramFiles}/Ninja/ninja.exe -ErrorAction SilentlyContinue))
    {
        ${Env:NINJA_HOME} = Join-Path ${Env:ProgramFiles} Ninja
        New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}/System32/ninja.exe" -Value "${Env:NINJA_HOME}/ninja.exe"
        Write-Host "Ninja installed successfully."
    }
    else
    {
        Write-Host "Ninja installation Failed. Please install manually: ${DownloadURL}"
        Exit 1
    }
}

# ================================================================================
# Import VC env is only necessary for non-VS (such as ninja) build.
# ================================================================================

if (${Env:VSCMD_VER} -eq $null)
{
    Invoke-Expression $($(cmd /c "`"${Env:ProgramFiles(x86)}/Microsoft Visual Studio/2017/Enterprise/VC/Auxiliary/Build/vcvarsall.bat`" x64 & set") -Match '^.+=' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
}

# ================================================================================
# Summary
# ================================================================================

Write-Host "================================================================================"
Write-Host "| Detected Toolchains"
Write-Host "--------------------------------------------------------------------------------"
Write-Host "| Perl Home:              ${Env:PERL_HOME}"
Write-Host "| NASM Home:              ${Env:NASM_HOME}"
Write-Host "| Python Home:            ${Env:PYTHONHOME}"
Write-Host "| Ninja Home:             ${Env:NINJA_HOME}"
Write-Host "| Visual Studio Toolset:  ${Env:VCToolsInstallDir}"
Write-Host "================================================================================"
