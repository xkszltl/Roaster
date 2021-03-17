#Requires -RunAsAdministrator

if (-Not $Env:ROASTER_TOOLCHAIN_COMMITED)
{
    # ================================================================================
    # Restore environment variables, including potential updates.
    # ================================================================================
    foreach ($env in [System.Environment]::GetEnvironmentVariables("Machine").GetEnumerator())
    {
        if ($env.Name -eq "PATH" -or $env.Name.StartsWith("CUDA"))
        {
            Write-Host "Restore environment var $($env.Name) to $($env.Value)"
            [Environment]::SetEnvironmentVariable($env.Name, $env.Value)
        }
    }

    # ================================================================================
    # Path longer than 260 may resolve to some obscure errors.
    # Fix in registry.
    # ================================================================================

    Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -Value 1 -Force

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # ================================================================================
    # Perl
    # ================================================================================

    ${Env:PERL_HOME} = "$(Get-Command -Name perl -ErrorAction SilentlyContinue | select -ExpandProperty Source | Split-Path -Parent)"

    if (${Env:PERL_HOME} -eq $null -or -not $(Test-Path ${Env:PERL_HOME}/perl.exe -ErrorAction SilentlyContinue))
    {
        ${Env:PERL_HOME} = Join-Path C:/Perl64 bin
    }

    if (${Env:PERL_HOME} -eq $null -or -not $(Test-Path ${Env:PERL_HOME}/perl.exe -ErrorAction SilentlyContinue))
    {
        $perl_ver="5.28.1.2801-MSWin32-x64-24563874"
        $DownloadURL = "https://downloads.activestate.com/ActivePerl/releases/" + $(${perl_ver} -replace '-.*','') + "/ActivePerl-${perl_ver}.exe"
        $DownloadPath = "${Env:SCRATCH}/ActivePerl-${perl_ver}.exe"
        Write-Host "Downloading ActivePerl..."
        Invoke-WebRequest -Uri $DownloadURL -OutFile $DownloadPath
        Write-Host "Installing ActivePerl..."
        & $DownloadPath /passive InstallAllUsers=1 PrependPath=1 | Out-Null
        if ($(Test-Path C:/Perl64/bin/perl.exe -ErrorAction SilentlyContinue))
        {
            ${Env:PERL_HOME} = Join-Path C:/Perl64 bin
            Write-Host "ActivePerl installed successfully."
        }
        else
        {
            Write-Host "ActivePerl installation Failed. Please install manually: ${DownloadURL}"
            exit 1
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
        $nasm_ver="2.15.05"
        $DownloadURL = "https://www.nasm.us/pub/nasm/releasebuilds/${nasm_ver}/win64/nasm-${nasm_ver}-installer-x64.exe"
        $DownloadPath = "${Env:SCRATCH}/nasm-${nasm_ver}-installer-x64.exe"
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
            exit 1
        }
    }

    ${Env:PATH} = "${Env:NASM_HOME};${Env:PATH}"

    # ================================================================================
    # Python
    # ================================================================================

    ${Env:PYTHONHOME} = "$(Get-Command -Name python -ErrorAction SilentlyContinue | select -ExpandProperty Source | Split-Path -Parent)"

    if (${Env:PYTHONHOME} -eq $null -or -not $(Test-Path ${Env:PYTHONHOME}/python.exe -ErrorAction SilentlyContinue))
    {
        ${Env:PYTHONHOME} = Join-Path ${Env:ProgramFiles} Python39
    }

    if (${Env:PYTHONHOME} -eq $null -or -not $(Test-Path ${Env:PYTHONHOME}/python.exe -ErrorAction SilentlyContinue))
    {
        $py_ver="3.9.1"
        $DownloadURL = "https://www.python.org/ftp/python/${py_ver}/python-${py_ver}-amd64.exe"
        $DownloadPath = "${Env:SCRATCH}/python-${py_ver}-amd64.exe"
        Write-Host "Downloading Python..."
        Invoke-WebRequest -Uri $DownloadURL -OutFile $DownloadPath
        Write-Host "Installing Python..."
        & $DownloadPath /passive InstallAllUsers=1 PrependPath=1 | Out-Null
        if ($(Test-Path ${Env:ProgramFiles}/Python39/python.exe -ErrorAction SilentlyContinue))
        {
            ${Env:PYTHONHOME} = Join-Path ${Env:ProgramFiles} Python39
            Write-Host "Python installed successfully."
        }
        else
        {
            Write-Host "Python installation Failed. Please install manually: ${DownloadURL}"
            exit 1
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
        $ninja_repo="https://github.com/ninja-build/ninja.git"
        $ninja_ver='v' + $($(git ls-remote --tags $ninja_repo) -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v', '' | sort { [Version]$_ })[-1]
        $DownloadURL = "https://github.com/ninja-build/ninja/releases/download/${ninja_ver}/ninja-win.zip"
        $DownloadPath = "${Env:SCRATCH}/ninja-win.zip"
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
            exit 1
        }
    }

    # ================================================================================
    # Import VC env is only necessary for non-VS (such as ninja) build.
    # ================================================================================

    if (${Env:VSCMD_VER} -eq $null)
    {
        ${VS_HOME} = & "${Env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe" `
                        -latest                                                                 `
                        -products *                                                             `
                        -property installationPath                                              `
                        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64

        $vcvars_script = "${VS_HOME}/VC/Auxiliary/Build/vcvarsall.bat"
        if (-Not (Test-Path $vcvars_script))
        {
            Write-Host "Unable to locate Visual Studio command file: vcvarsall.bat. This is required for VC env import."
            exit 1
        }

        Invoke-Expression $($(cmd /c "`"${VS_HOME}/VC/Auxiliary/Build/vcvarsall.bat`" x64 10.0.16299.0 & set") -Match '^.+=' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)

        if ((${Env:VCToolsVersion} -eq $null) -or -not ${Env:VCToolsVersion}.StartsWith("14.2"))
        {
            # MSVC internal version numbering
            # https://en.wikipedia.org/wiki/Microsoft_Visual_C++
            Write-Host "Invalid MSVC version: ${Env:VCToolsVersion}. vc142 is expetced."
            exit 1
        }

        if ((${Env:WindowsSDKVersion} -eq $null) -or -not ${Env:WindowsSDKVersion}.StartsWith("10.0.16299.0"))
        {
            Write-Host "Invalid WinSDK version: ${Env:WindowsSDKVersion}, 10.0.16299.0 (Redstone3) is expetced."
            exit 1
        }
    }
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

# ================================================================================
# Commit
# ================================================================================

$Env:ROASTER_TOOLCHAIN_COMMITED = $true
