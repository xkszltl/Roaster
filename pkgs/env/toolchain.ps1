#Requires -RunAsAdministrator

# ================================================================================
# PYTHONHOME
# ================================================================================

${Env:PYTHONHOME}="${Env:ProgramFiles(x86)}/Microsoft Visual Studio/Shared/Python36_64"

# ================================================================================
# Summary
# ================================================================================

echo "================================================================================"
echo "| Detected Toolchains"
echo "--------------------------------------------------------------------------------"
echo "| Python Home:            ${Env:PYTHONHOME}"
echo "| Visual Studio Toolset:  ${Env:VCToolsInstallDir}"
echo "================================================================================"
