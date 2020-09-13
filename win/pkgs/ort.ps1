#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

& "${Env:PYTHONHOME}/python.exe" -m pip install -U numpy | Out-Null

pushd ${Env:SCRATCH}
$repo="${Env:GIT_MIRROR}/microsoft/onnxruntime.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root= Join-Path "${Env:SCRATCH}" "$proj"

cmd /c rmdir /S /Q "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

# Use latest release.
$latest_ver = 'v' + $($(git ls-remote --tags "$repo") -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v','' | sort {[Version]$_})[-1]

# Use latest release branch.
# $latest_ver = 'rel-' + $($(git ls-remote --heads "$repo") -match '.*refs/heads/rel-[0-9\.]*$' -replace '.*refs/heads/rel-','' | sort {[Version]$_})[-1]

# Use master.
# $latest_ver = 'master'

git clone --recursive -b "$latest_ver" -j100 "$repo"
pushd "$root"

# ================================================================================
# Build Options
# ================================================================================

$update_gtest = $true
$update_onnx = $false
$update_protobuf = $false
$use_bat = $false

# ================================================================================
# Experimental PR
# ================================================================================

# Patch unit tests for MSVC LTO bug: https://github.com/microsoft/onnxruntime/pull/4713
git cherry-pick 2e3ccc75

# ================================================================================
# Patch
# ================================================================================

git remote add patch https://github.com/xkszltl/onnxruntime.git
git fetch patch

# ================================================================================
# Update GTest
# ================================================================================

if ($update_gtest)
{
    pushd cmake/external/googletest
    git fetch --tags
    $gtest_latest_ver='release-' + $($(git tag) -match '^release-[0-9\.]*$' -replace '^release-','' | sort {[Version]$_})[-1]
    git checkout "$gtest_latest_ver"
    git submodule update --init
    popd
}

# ================================================================================
# Update ONNX and its PyBind
#
# Warning:
#     ONNX Breaking change on Mar 11, 2019 causes build error in Ort.
#     https://github.com/onnx/onnx/pull/1834
# ================================================================================

if ($update_onnx)
{
    pushd cmake/external/onnx
    git pull origin master
    git submodule update --init --recursive

    pushd third_party/pybind11
    git fetch --tags
    $pybind_latest_ver='v' + $($(git tag) -match '^v[0-9\.]*$' -replace '^v','' | sort {[Version]$_})[-1]
    git checkout "$pybind_latest_ver"
    git submodule update --init --recursive
    popd

    git --no-pager diff
    git commit -am "Automatic git submodule updates."

    popd
}

# ================================================================================
# Update Protobuf
# ================================================================================

if ($update_protobuf)
{
    pushd cmake/external/protobuf
    git fetch --tags
    $pb_latest_ver='v' + $($(git tag) -match '^v[0-9\.]*$' -replace '^v','' | sort {[Version]$_})[-1]
    git checkout "$pb_latest_ver"
    git remote add patch https://github.com/xkszltl/protobuf.git
    git fetch patch
    git submodule update --init
    popd
}

# ================================================================================
# Commit
# ================================================================================

git --no-pager diff
git commit -am "Automatic git submodule updates."

# ================================================================================
# Build
# ================================================================================

if (-not $use_bat)
{
    mkdir build
    pushd build
}

if ($use_bat)
{
    ./build.bat                                         `
        --build_shared_lib                              `
        --cmake_extra_defines                           `
            BOOST_ROOT=`"${Env:ProgramFiles}/boost`"    `
            CMAKE_C_FLAGS=`"/w`"                        `
            CMAKE_CXX_FLAGS=`"/w`"                      `
        --config=Release                                `
        --use_mklml

    exit 1
}
else
{
    # Ort team is removing prebuilt protobuf.
    #     -DONNX_CUSTOM_PROTOC_EXECUTABLE="${Env:ProgramFiles}/protobuf/bin/protoc.exe"
    #     -Donnxruntime_USE_PREBUILT_PB=ON
    cmake                                                                               `
        -A x64                                                                          `
        -DBOOST_ROOT="${Env:ProgramFiles}/boost"                                        `
        -DBUILD_SHARED_LIBS=OFF                                                         `
        -DCMAKE_C_FLAGS="/GL /MP /Zi /arch:AVX2"                                        `
        -DCMAKE_CUDA_FLAGS="-gencode=arch=compute_35,code=sm_35 -gencode=arch=compute_37,code=sm_37"    `
        -DCMAKE_CXX_FLAGS="/EHsc /GL /MP /Zi /arch:AVX2"                                `
        -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"                    `
        -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/onnxruntime"                        `
        -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                                       `
        -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"                 `
        -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                                 `
        -DCUDA_VERBOSE_BUILD=ON                                                         `
        -Deigen_SOURCE_PATH="${Env:ProgramFiles}/Eigen3/include/eigen3"                 `
        -Donnxruntime_BUILD_CSHARP=OFF                                                  `
        -Donnxruntime_BUILD_SHARED_LIB=ON                                               `
        -Donnxruntime_CUDA_HOME="$(Split-Path (Get-Command nvcc).Source -Parent)/.."    `
        -Donnxruntime_CUDNN_HOME="$(Split-Path (Get-Command nvcc).Source -Parent)/.."   `
        -Donnxruntime_ENABLE_PYTHON=ON                                                  `
        -Donnxruntime_RUN_ONNX_TESTS=ON                                                 `
        -Donnxruntime_ENABLE_LANGUAGE_INTEROP_OPS=ON                                    `
        -Donnxruntime_ENABLE_LTO=OFF                                                    `
        -Donnxruntime_PREFER_SYSTEM_LIB=OFF                                             `
        -Donnxruntime_TENSORRT_HOME='${Env:ProgramFiles}/tensorrt'                      `
        -Donnxruntime_USE_CUDA=ON                                                       `
        -Donnxruntime_USE_DNNL=ON                                                       `
        -Donnxruntime_USE_EIGEN_FOR_BLAS=ON                                             `
        -Donnxruntime_USE_FULL_PROTOBUF=ON                                              `
        -Donnxruntime_USE_JEMALLOC=OFF                                                  `
        -Donnxruntime_USE_LLVM=OFF                                                      `
        -Donnxruntime_USE_MKLML=OFF                                                     `
        -Donnxruntime_USE_NGRAPH=OFF                                                    `
        -Donnxruntime_USE_NUPHAR=OFF                                                    `
        -Donnxruntime_USE_OPENBLAS=OFF                                                  `
        -Donnxruntime_USE_OPENMP=OFF                                                    `
        -Donnxruntime_USE_PREINSTALLED_EIGEN=OFF                                        `
        -Donnxruntime_USE_TENSORRT=OFF                                                  `
        -Donnxruntime_USE_TVM=OFF                                                       `
        -G"Visual Studio 16 2019"                                                       `
        -T"host=x64"                                                                    `
        ../cmake

    cmake --build . --config Release -- -maxcpucount
    if (-Not $?)
    {
        echo "Failed to build."
        echo "Retry with single thread for logging."
        echo "You may Ctrl-C this if you don't need the log file."
        cmake --build . --config Release 2>&1 | tee ${Env:SCRATCH}/${proj}.log
        exit 1
    }
}

$model_path = "${Env:SCRATCH}/onnxruntime_models.zip"
rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${model_path}.downloading"
if ($true)
{
    if (-not $(Test-Path $model_path))
    {
        & "${Env:ProgramFiles}/CURL/bin/curl.exe" --retry 5 -fkSL "https://onnxruntimetestdata.blob.core.windows.net/models/20190419.zip" -o "${model_path}.downloading"
        mv -Force "${model_path}.downloading" "${model_path}"
    }

    if (Get-Command -Name unzip -ErrorAction SilentlyContinue)
    {
        unzip -ou "${model_path}" -d "${model_path}.d"
        cmd /c mklink /D models "`"${model_path}.d`""
    }
    else
    {
        Expand-Archive "${model_path}" "models"
    }

    $ErrorActionPreference="SilentlyContinue"
    cmake --build . --config Release --target run_tests -- -maxcpucount
    if (-Not $?)
    {
        echo "Check failed but we temporarily bypass it. Trying to reproduce:"
        pushd Release
        ./onnxruntime_test_all.exe
        ./onnxruntime_shared_lib_test.exe
        popd
    }
    $ErrorActionPreference="Stop"
}

cmd /c rmdir /S /Q "${Env:ProgramFiles}/onnxruntime"
cmake --build . --config Release --target install -- -maxcpucount
cmd /c xcopy    /i /f /y "pdb\Release\*.pdb"                "${Env:ProgramFiles}\onnxruntime\bin"
# cmd /c xcopy /e /i /f /y "..\cmake\external\gsl\include"    "${Env:ProgramFiles}\onnxruntime\include"
# cmd /c xcopy /e /i /f /y "..\cmake\external\onnx\onnx"      "${Env:ProgramFiles}\onnxruntime\include\onnx"
# cmd /c xcopy    /i /f /y "onnx\*.pb.h"                      "${Env:ProgramFiles}\onnxruntime\include\onnx"
# cmd /c xcopy    /i /f /y "onnx\Release\*.lib"               "${Env:ProgramFiles}\onnxruntime\lib"
# cmd /c xcopy    /i /f /y "onnxruntime_config.h"             "${Env:ProgramFiles}\onnxruntime\include\onnxruntime"
# cmd /c xcopy /e /i /f /y "..\onnxruntime\core"              "${Env:ProgramFiles}\onnxruntime\include\onnxruntime\core"
Get-ChildItem "${Env:ProgramFiles}/onnxruntime" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }
Get-ChildItem "${Env:ProgramFiles}/onnxruntime" -Filter *.exe -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

onnx_test_runner -e cpu ./models
onnx_test_runner -e dnnl ./models
onnx_test_runner -e cuda ./models

popd
popd
cmd /c rmdir /S /Q "$root"
popd
