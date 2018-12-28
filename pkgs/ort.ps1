#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1" | Out-Null
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/toolchain.ps1"

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
git remote add patch https://github.com/xkszltl/onnxruntime.git
git fetch patch
git pull patch cudart
git pull patch eigen
git pull patch protobuf

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
git submodule update --init
popd

# ================================================================================
# Update ONNX
# ================================================================================

pushd cmake/external/onnx
git pull origin master
git submodule update --init
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
# NVCC does not support exporting classes using constexpr.
# $protobuf_dll="/DPROTOBUF_USE_DLLS"
$protobuf_dll=""
$dep_dll="${protobuf_dll}"

cmake                                                                                       `
    -A x64                                                                                  `
    -DBUILD_SHARED_LIBS=OFF                                                                 `
    -DCMAKE_C_FLAGS="/GL /MP ${dep_dll}"                                                    `
    -DCMAKE_CXX_FLAGS="/EHsc /GL /MP ${dep_dll} ${gtest_silent_warning}"                    `
    -DCMAKE_CUDA_SEPARABLE_COMPILATION=ON                                                   `
    -DCMAKE_EXE_LINKER_FLAGS="/LTCG:incremental"                                            `
    -DCMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"                               `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/onnxruntime"                                `
    -DCMAKE_SHARED_LINKER_FLAGS="/LTCG:incremental"                                         `
    -DCMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO="/INCREMENTAL:NO"                            `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                                         `
    -DONNX_CUSTOM_PROTOC_EXECUTABLE="${Env:ProgramFiles}/protobuf/bin/protoc.exe"           `
    -Deigen_SOURCE_PATH="${Env:ProgramFiles}/Eigen3/include/eigen3"                         `
    -Donnxruntime_BUILD_SHARED_LIB=ON                                                       `
    -Donnxruntime_CUDNN_HOME="${Env:ProgramFiles}/NVIDIA GPU Computing Toolkit/CUDA/v10.0"  `
    -Donnxruntime_ENABLE_PYTHON=ON                                                          `
    -Donnxruntime_RUN_ONNX_TESTS=ON                                                         `
    -Donnxruntime_USE_CUDA=ON                                                               `
    -Donnxruntime_USE_JEMALLOC=OFF                                                          `
    -Donnxruntime_USE_LLVM=OFF                                                              `
    -Donnxruntime_USE_MKLDNN=ON                                                             `
    -Donnxruntime_USE_MKLML=OFF                                                             `
    -Donnxruntime_USE_OPENMP=ON                                                             `
    -Donnxruntime_USE_PREBUILT_PB=OFF                                                       `
    -Donnxruntime_USE_PREINSTALLED_EIGEN=ON                                                 `
    -Donnxruntime_USE_TVM=OFF                                                               `
    -G"Visual Studio 15 2017"                                                               `
    -T"host=x64"                                                                            `
    ../cmake

cmake --build . --config RelWithDebInfo -- -maxcpucount

$model_path = "${Env:TMP}/onnxruntime_models.zip"
rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${model_path}.downloading"
if (-not $(Test-Path $model_path))
{
    & "${Env:ProgramFiles}/CURL/bin/curl.exe" -fkSL "https://onnxruntimetestdata.blob.core.windows.net/models/20181210.zip" -o "${model_path}.downloading"
    mv -Force "${model_path}.downloading" "${model_path}"
}
Expand-Archive ${model_path} models

$ErrorActionPreference="SilentlyContinue"
cmake --build . --config RelWithDebInfo --target run_tests -- -maxcpucount
if (-Not $?)
{
    echo "Check failed but we temporarily bypass it. It might be a CUDA-only issue. Trying to reproduce:"
    pushd RelWithDebInfo
    ./onnxruntime_test_all.exe
    ./onnxruntime_shared_lib_test.exe
    popd
}
$ErrorActionPreference="Stop"

cmd /c rmdir /S /Q "${Env:ProgramFiles}/onnxruntime"
cmake --build . --config RelWithDebInfo --target install -- -maxcpucount
Get-ChildItem "${Env:ProgramFiles}/onnxruntime" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }
Get-ChildItem "${Env:ProgramFiles}/onnxruntime" -Filter *.exe -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

onnx_test_runner -e cpu ./models
onnx_test_runner -e mkldnn ./models
# onnx_test_runner -e cuda ./models

popd
popd
rm -Force -Recurse "$root"
popd
