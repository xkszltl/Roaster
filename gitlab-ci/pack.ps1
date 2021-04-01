Param(
    [Parameter(Mandatory = $True)]
    [string] $packages,

    [Parameter(Mandatory = $True)]
    [string] $output
)

$ErrorActionPreference="Stop"

mkdir $output

$nuspec_root = "$PSScriptRoot/../win/nuget"

foreach ($name in $packages.Split(","))
{
    $pkgs = Get-ChildItem $nuspec_root -Filter "$name" -Directory
    if ($pkgs.Length -eq 0)
    {
        Write-Error "Invalid package name `"$name`"".
    }

    foreach ($pkg in $pkgs)
    {
        $pkg = $pkg.Name

        Write-Host "Package $pkg."
        $nuspec_dir = "$nuspec_root/$pkg"
        if (-Not (Test-Path $nuspec_dir))
        {
            Write-Error "Invalid package name $pkg."
        }
    
        if (Test-Path "$output/$pkg")
        {
            Write-Error "Package $pkg already exists."
        }
    
        Copy-Item -Recurse $nuspec_dir $output
    
        if ($pkg -eq "cuda" -or $pkg -eq "cublas" -or $pkg -eq "cufft" -or $pkg -eq "cusolver" -or $pkg -eq "cusparse")
        {
            $prefix = ${Env:CUDA_PATH}
            if ($null -eq $prefix)
            {
                Write-Error "CUDA is not installed."
            } 
        }
        elseif ($pkg -eq "cudnn" -or $pkg -eq "cudnn_adv" -or $pkg -eq "cudnn_cnn" -or $pkg -eq "cudnn_ops")
        {
            $prefix = ${Env:CUDA_PATH}
        }
        elseif ($pkg -eq "eigen")
        {
            $prefix = "${Env:ProgramFiles}/Eigen3"
        }
        elseif ($pkg -eq "jsoncpp" -or $pkg -eq "jsoncpp-dev")
        {
            $prefix = "${Env:ProgramFiles}/jsoncpp"
        }
        elseif ($pkg -eq "mkldnn" -or $pkg -eq "mkldnn-dev")
        {
            $prefix = "${Env:ProgramFiles}/oneDNN"
        }
        elseif ($pkg -eq "onnx" -or $pkg -eq "onnx-dev")
        {
            $prefix = "${Env:ProgramFiles}/ONNX"
        }
        elseif ($pkg -eq "opencv" -or $pkg -eq "opencv-dev")
        {
            $prefix = "${Env:ProgramFiles}/opencv"
        }
        elseif ($pkg -eq "protobuf" -or $pkg -eq "protobuf-dev")
        {
            $prefix = "${Env:ProgramFiles}/protobuf"
        }
        elseif ($pkg -eq "rocksdb" -or $pkg -eq "rocksdb-dev")
        {
            $prefix = "${Env:ProgramFiles}/rocksdb"
        }
        elseif ($pkg -eq "pytorch" -or $pkg -eq "pytorch-dev" -or $pkg -eq "pytorch-debuginfo")
        {
            $prefix = "${Env:ProgramFiles}/Caffe2"
        }
        elseif ($pkg -eq "cream" -or $pkg -eq "cream-dev")
        {
            $prefix = "${Env:ProgramFiles}/Cream"
        }
        elseif ($pkg -eq "ort" -or $pkg -eq "ort-dev")
        {
            $prefix = "${Env:ProgramFiles}/onnxruntime"
        }
        elseif ($pkg -eq "mkl" -or $pkg -eq "mkl-vml" -or $pkg -eq "mkl-dev")
        {
            $prefix = "${Env:ProgramFiles(x86)}/IntelSWTools"
        }
        elseif ($pkg -eq "daal" -or $pkg -eq "daal-dev" -or $pkg -eq "iomp" -or $pkg -eq "ipp" -or $pkg -eq "ipp-dev" -or $pkg -eq "mpi" -or $pkg -eq "tbb")
        {
            $prefix = "${Env:ProgramFiles(x86)}/IntelSWTools"
        }
        elseif ($pkg -eq "c-ares")
        {
            $prefix = "${Env:ProgramFiles(x86)}/c-ares"
        }
        elseif ($pkg -eq "grpc")
        {
            $prefix = "${Env:ProgramFiles(x86)}/grpc"
        }
        elseif ($pkg -eq "benchmark")
        {
            $prefix = "${Env:ProgramFiles(x86)}/benchmark"
        }
        else
        {
            $prefix = "${Env:ProgramFiles}/$pkg"
        }
    
        if (-Not (Test-Path $prefix))
        {
            Write-Error "Prefix dir $prefix is invalid."
        }
    
        New-Item -ItemType SymbolicLink -Path "$output/$pkg/$pkg" -Value $prefix    
    }
}