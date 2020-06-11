################################################################################
# Intel may ask you to register on their website before downloading libraries.
# Please follow their instructions and procedures.
#
# You agree to take full responsibility for using this script, and relief
# authors from any liability of not acquiring data in the normal way.
################################################################################

#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

pushd ${Env:SCRATCH}
$proj="cudnn"
$root="${Env:SCRATCH}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

mkdir "$root"
pushd "$root"

${Env:Path} = [System.Environment]::GetEnvironmentVariable("Path","Machine")

if (${Env:CUDA_PATH} -ne $null)
{
    $CUDA_HOME=${Env:CUDA_PATH}
}
elseif ([System.Environment]::GetEnvironmentVariable("CUDA_PATH","Machine") -ne $null)
{
    $CUDA_HOME=[System.Environment]::GetEnvironmentVariable("CUDA_PATH","Machine")
}
else
{
    $CUDA_HOME="$(Split-Path (Get-Command nvcc).Source -Parent)/.."
}
Write-Host "Found CUDA ${CUDA_HOME}."
$cudnn_url="https://developer.download.nvidia.com/compute/redist/cudnn"

# Update the URL as new version releases.

Write-Host -NoNewline "Scanning for latest release of cuDNN "

# URL in the form of:
#     https://developer.download.nvidia.com/compute/redist/cudnn/v7.6.2/cudnn-10.1-windows10-x64-v7.6.2.24.zip

for ($i=7; ($i -ge 7) -and (-not (Test-Path cudnn.zip)); $i--)
{
    for ($j=6; ($j -ge 0) -and (-not (Test-Path cudnn.zip)); $j--)
    {
        for ($k=5; ($k -ge 0) -and (-not (Test-Path cudnn.zip)); $k--)
        {
            for ($l=32; ($l -ge 0) -and (-not (Test-Path cudnn.zip)); $l--)
            {
                $cudnn_name="cudnn-$((nvcc --version) -match ' release ([0-9\.]*)' -replace '.* release ([0-9\.]*).*','${1}')-windows10-x64-v${i}.${j}.${k}.${l}.zip"
                Write-Host -NoNewline '.'
                $ErrorActionPreference="SlightlyContinue"
                & "${Env:ProgramFiles}/CURL/bin/curl.exe" -fksSIL "${cudnn_url}/v${i}.${j}.${k}/${cudnn_name}" | Out-Null
                if ($?)
                {
                    $ErrorActionPreference="Stop"
                    echo ''
                    echo "Found cuDNN v${i}.${j}.${k}.${l}"
                    & "${Env:ProgramFiles}/CURL/bin/curl.exe" -fkSL "${cudnn_url}/v${i}.${j}.${k}/${cudnn_name}" -o "cudnn.zip"
                }
                $ErrorActionPreference="Stop"
            }
        }
    }
}

if (-not (Test-Path cudnn.zip))
{
    echo "Failed to detect the most recent cuDNN."
    rm -Force -Recurse "$root"
    popd
    exit 1;
}

Expand-Archive "cudnn.zip"
Move-Item -Force -Destination "${CUDA_HOME}/bin/" "cudnn/cuda/bin/*"
Move-Item -Force -Destination "${CUDA_HOME}/include/" "cudnn/cuda/include/*"
Move-Item -Force -Destination "${CUDA_HOME}/lib/x64/" "cudnn/cuda/lib/x64/*"
Move-Item -Force -Destination "${CUDA_HOME}/" "cudnn/cuda/*.txt"

popd
rm -Force -Recurse "$root"
popd
