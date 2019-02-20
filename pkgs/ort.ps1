#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

& "${Env:PYTHONHOME}/python.exe" -m pip install -U numpy | Out-Null

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/microsoft/onnxruntime.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root= Join-Path "${Env:TMP}" "$proj"

cmd /c rmdir /S /Q "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

git clone --recursive -j100 "$repo"
pushd "$root"

# ================================================================================
# Experimental PR
# ================================================================================

# ================================================================================
# Patch
# ================================================================================

git remote add patch https://github.com/xkszltl/onnxruntime.git
git fetch patch

# ================================================================================
# LotusPlus
# ================================================================================

git remote add lotusplus https://msresearch.visualstudio.com/DefaultCollection/OneOCR/_git/LotusPlus
git pull --no-edit lotusplus custom_ops

if (-Not $?)
{
    echo "Failed to integrate LotusPlus"
    exit 1
}

# ================================================================================
# Update GTest
# ================================================================================

pushd cmake/external/googletest
git fetch --tags
$gtest_latest_ver='release-' + $($(git tag) -match '^release-[0-9\.]*$' -replace '^release-','' | sort {[Version]$_})[-1]
git checkout "$gtest_latest_ver"
git submodule update --init
popd

# ================================================================================
# Update Protobuf
# ================================================================================

pushd cmake/external/protobuf
git fetch --tags
$pb_latest_ver='v' + $($(git tag) -match '^v[0-9\.]*$' -replace '^v','' | sort {[Version]$_})[-1]
git checkout "$pb_latest_ver"
git remote add patch https://github.com/xkszltl/protobuf.git
git fetch patch
git cherry-pick patch/constexpr-3.6
git submodule update --init
popd

# ================================================================================
# Update ONNX and its PyBind
# ================================================================================

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

# ================================================================================
# Commit
# ================================================================================

git --no-pager diff
git commit -am "Automatic git submodule updates."

# ================================================================================
# Build
# ================================================================================

mkdir build
pushd build

# Copy MKL's environment variables from ".bat" file to PowerShell.
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 vs2017 & set") -Match '^MKL(_|ROOT)' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 vs2017 & set") -Match '^LIB' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 vs2017 & set") -Match '^CPATH' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 vs2017 & set") -Match '^INCLUDE' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)

$gtest_silent_warning="/D_SILENCE_STDEXT_HASH_DEPRECATION_WARNINGS /D_SILENCE_TR1_NAMESPACE_DEPRECATION_WARNING"
$protobuf_dll="/DPROTOBUF_USE_DLLS"
$dep_dll="${protobuf_dll}"

# Turn off CUDA temporarily until Ort team switch back to static cudart.
cmake                                                                                   `
    -A x64                                                                              `
    -DBOOST_ROOT="${Env:ProgramFiles}/boost"                                            `
    -DBUILD_SHARED_LIBS=OFF                                                             `
    -DCMAKE_C_FLAGS="/GL /MP /Zi /arch:AVX2 ${dep_dll}"                                 `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP /Zi /arch:AVX2 ${dep_dll} ${gtest_silent_warning}" `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"                        `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/onnxruntime"                            `
    -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                                           `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"                     `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                                     `
    -DCUDA_VERBOSE_BUILD=ON                                                             `
    -DONNX_CUSTOM_PROTOC_EXECUTABLE="${Env:ProgramFiles}/protobuf/bin/protoc.exe"       `
    -Deigen_SOURCE_PATH="${Env:ProgramFiles}/Eigen3/include/eigen3"                     `
    -Donnxruntime_BUILD_SHARED_LIB=ON                                                   `
    -Donnxruntime_CUDNN_HOME="$(Split-Path (Get-Command nvcc).Source -Parent)/.."       `
    -Donnxruntime_ENABLE_PYTHON=ON                                                      `
    -Donnxruntime_RUN_ONNX_TESTS=ON                                                     `
    -Donnxruntime_USE_CUDA=OFF                                                          `
    -Donnxruntime_USE_JEMALLOC=OFF                                                      `
    -Donnxruntime_USE_LLVM=OFF                                                          `
    -Donnxruntime_USE_MKLDNN=ON                                                         `
    -Donnxruntime_USE_MKLML=ON                                                          `
    -Donnxruntime_USE_OPENMP=OFF                                                        `
    -Donnxruntime_USE_PREBUILT_PB=ON                                                    `
    -Donnxruntime_USE_PREINSTALLED_EIGEN=ON                                             `
    -Donnxruntime_USE_TVM=OFF                                                           `
    -G"Visual Studio 15 2017"                                                           `
    -T"host=x64"                                                                        `
    ../cmake

cmake --build . --config Release -- -maxcpucount
if (-Not $?)
{
    echo "Failed to build."
    echo "Retry with single thread for logging."
    echo "You may Ctrl-C this if you don't need the log file."
    cmake --build . --config Release 2>&1 | tee ${Env:TMP}/${proj}.log
    exit 1
}

$model_path = "${Env:TMP}/onnxruntime_models.zip"
rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${model_path}.downloading"
if (-not $(Test-Path $model_path))
{
    & "${Env:ProgramFiles}/CURL/bin/curl.exe" -fkSL "https://onnxruntimetestdata.blob.core.windows.net/models/20181210.zip" -o "${model_path}.downloading"
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

cmd /c rmdir /S /Q "${Env:ProgramFiles}/onnxruntime"
cmake --build . --config Release --target install -- -maxcpucount
cmd /c xcopy    /i /f /y "Release\mklml.dll"                "${Env:ProgramFiles}\onnxruntime\bin"
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
onnx_test_runner -e mkldnn ./models
onnx_test_runner -e cuda ./models

popd
popd
cmd /c rmdir /S /Q "$root"
popd
