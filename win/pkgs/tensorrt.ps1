################################################################################
# Nvidia may ask you to register on their website before downloading libraries.
# Please follow their instructions and procedures.
#
# You agree to take full responsibility for using this script, and relief
# authors from any liability of not acquiring data in the normal way.
################################################################################

#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

pushd ${Env:SCRATCH}
$proj="tensorrt"
$root="${Env:SCRATCH}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

mkdir "$root"
pushd "$root"

# Update the URL as new version releases.
$trt_mirror="https://github.com/xkszltl/Roaster/releases/download/trt"
$trt_name="TensorRT-7.2.2.3.Windows10.x86_64.cuda-$((nvcc --version) -match ' release ([0-9\.]*)' -replace '.* release ([0-9\.]*).*','${1}' -replace '11.2','11.1').cudnn8.0.zip"

if (-not (Test-Path "../${trt_name}"))
{
    rm -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "../TensorRT-*.zip"
    & "${Env:ProgramFiles}/CURL/bin/curl.exe" -fkSL "${trt_mirror}/${trt_name}" -o "${trt_name}.downloading"
    Move-Item -Force "${trt_name}.downloading" "../${trt_name}"
}

mkdir "${trt_name}.extracting.d"
Expand-Archive "../${trt_name}" "${trt_name}.extracting.d"
Move-Item -Force "${trt_name}.extracting.d/TensorRT-*" "tensorrt"
rm -Force -Recurse "${trt_name}.extracting.d"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/tensorrt"
Move-Item -Force "tensorrt" "${Env:ProgramFiles}/tensorrt"
Get-ChildItem "${Env:ProgramFiles}/tensorrt" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
rm -Force -Recurse "$root"
popd
