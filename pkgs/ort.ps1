#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1" | Out-Null
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/toolchain.ps1" | Out-Null

# ================================================================================
# Import VC env is only necessary for non-VS (such as ninja) build.
# ================================================================================

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
    -DBUILD_SHARED_LIBS=OFF                                                                 `
    -DCMAKE_C_FLAGS="/MP ${dep_dll}"                                                        `
    -DCMAKE_CXX_FLAGS="/EHsc /MP ${dep_dll} ${gtest_silent_warning}"                        `
    -DCMAKE_CUDA_SEPARABLE_COMPILATION=ON                                                   `
    -DCMAKE_GENERATOR_PLATFORM=x64                                                          `
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
cmake --build . --config RelWithDebInfo --target run_tests -- -maxcpucount

cmd /c rmdir /S /Q "${Env:ProgramFiles}/onnxruntime"
cmake --build . --config RelWithDebInfo --target install -- -maxcpucount
Get-ChildItem "${Env:ProgramFiles}/onnxruntime" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
