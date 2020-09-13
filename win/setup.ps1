################################################################################
# Install all packages.
################################################################################

#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/pkgs/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

cd $PSScriptRoot

. "pkgs/env/scratch.ps1"
. "pkgs/env/toolchain.ps1"

# ================================================================================
# Install
# ================================================================================

foreach ($pkg in @(
    "cmake",
    "zlib",
    "openssl",
    "c-ares",
    "curl",
    "cuda",
    "cudnn",
    "tensorrt",
    "intel",
    "mklml",
    "freetype",
    "harfbuzz",
    "freetype", # Loop dependency between HarfBuzz/FreeType.
    "boost",
    "jsoncpp",
    "utf8proc",
    "eigen",
    "pybind11",
    "mkl-dnn",
    "gflags",
    "glog",
    "gtest",
    "benchmark",
    "snappy",
    "protobuf",
    "grpc",
    'opencv'
    "rocksdb",
    "onnx",
    "pytorch",
    "ort",
    ""))
{
    if ($pkg -eq "")
    {
        continue
    }

    if ($pkg -match '^#')
    {
        continue
    }

    if ($($args.Count -gt 1) -and -not $($pkg -in $args))
    {
        continue
    }

    Write-Host "Install `"$pkg`"."
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
    }
}

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:SCRATCH}"
Write-Host "Completed."
