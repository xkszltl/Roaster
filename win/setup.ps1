################################################################################
# Install all packages.
################################################################################

#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/pkgs/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

cd $PSScriptRoot

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
    "intel",
    "mklml",
    "freetype",
    "harfbuzz",
    "freetype", # Loop dependency between HarfBuzz/FreeType.
    "boost",
    "jsoncpp",
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
    "rocksdb",
    "onnx",
    "pytorch",
    "ort",
    "cream",
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

Write-Host "Completed."