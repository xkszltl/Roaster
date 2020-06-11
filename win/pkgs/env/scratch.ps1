#Requires -RunAsAdministrator

# ================================================================================
# Create scratch dir.
# ================================================================================

${Env:SCRATCH}="${Env:TMP}/roaster-scratch"

mkdir ${Env:SCRATCH}
