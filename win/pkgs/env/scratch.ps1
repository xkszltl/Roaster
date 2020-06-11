#Requires -RunAsAdministrator

# ================================================================================
# Create scratch dir.
# ================================================================================

${Env:SCRATCH}="${Env:TMP}/roaster-scratch"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:SCRATCH}"
mkdir "${Env:SCRATCH}"
