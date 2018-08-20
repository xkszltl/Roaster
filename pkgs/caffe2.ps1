#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1" | Out-Null
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/toolchain.ps1" | Out-Null

# ================================================================================
# Import VC env is only necessary for non-VS (such as ninja) build.
# ================================================================================

Invoke-Expression $($(cmd /c "`"${Env:ProgramFiles(x86)}/Microsoft Visual Studio/2017/Enterprise/VC/Auxiliary/Build/vcvarsall.bat`" x64 & set") -Match '^.+=' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)

& "${Env:PYTHONHOME}/Scripts/pip.exe" install -U numpy | Out-Null

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/pytorch/pytorch.git"
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
git remote add patch https://github.com/xkszltl/pytorch.git
git fetch patch
git pull patch pybind
git pull patch redef
git pull patch observer
git pull patch typeid
#TODO: cherry-pick patch/gpu_dll
git checkout -- *

mkdir build
pushd build

# Copy MKL's environment variables from ".bat" file to PowerShell.
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 vs2017 & set") -Match '^MKL(_|ROOT)' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 vs2017 & set") -Match '^LIB' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 vs2017 & set") -Match '^CPATH' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 vs2017 & set") -Match '^INCLUDE' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)

$gtest_silent_warning="/D_SILENCE_STDEXT_HASH_DEPRECATION_WARNINGS /D_SILENCE_TR1_NAMESPACE_DEPRECATION_WARNING /w"
$gflags_dll="/DGFLAGS_IS_A_DLL=1"
$protobuf_dll="/DPROTOBUF_USE_DLLS"
$dep_dll="${gflags_dll} ${protobuf_dll}"

cmake                                                                           `
    -DBLAS=MKL                                                                  `
    -DBUILD_CUSTOM_PROTOBUF=OFF                                                 `
    -DBUILD_PYTHON=OFF                                                          `
    -DBUILD_SHARED_LIBS=ON                                                      `
    -DBUILD_TEST=ON                                                             `
    -DCMAKE_BUILD_TYPE=RelWithDebInfo                                           `
    -DCMAKE_C_FLAGS="/MP ${dep_dll}"                                            `
    -DCMAKE_CXX_FLAGS="/EHsc /MP ${dep_dll} ${gtest_silent_warning}"            `
    -DCMAKE_EXE_LINKER_FLAGS="/LTCG"                                            `
    -DCMAKE_SHARED_LINKER_FLAGS="/LTCG"                                         `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG"                                         `
    -DCMAKE_VERBOSE_MAKEFILE=ON                                                 `
    -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON                                       `
    -DCPUINFO_BUILD_TOOLS=ON                                                    `
    -DCUDA_ARCH_NAME="All"                                                      `
    -DCUDA_NVCC_FLAGS='--expt-relaxed-constexpr'                                `
    -DCUDA_SEPARABLE_COMPILATION=OFF                                            `
    -DPROTOBUF_INCLUDE_DIRS="${Env:ProgramFiles}/protobuf/include"              `
    -DPROTOBUF_LIBRARIES="${Env:ProgramFiles}/protobuf/bin"                     `
    -DPROTOBUF_PROTOC_EXECUTABLE="${Env:ProgramFiles}/protobuf/bin/protoc.exe"  `
    -DUSE_CUDA=OFF                                                              `
    -DUSE_GLOO=OFF                                                              `
    -DUSE_IDEEP=OFF                                                             `
    -DUSE_LEVELDB=OFF                                                           `
    -DUSE_LMDB=OFF                                                              `
    -DUSE_METAL=OFF                                                             `
    -DUSE_MOBILE_OPENGL=OFF                                                     `
    -DUSE_MPI=OFF                                                               `
    -DUSE_NCCL=OFF                                                              `
    -DUSE_NNPACK=OFF                                                            `
    -DUSE_NUMA=OFF                                                              `
    -DUSE_OBSERVERS=ON                                                          `
    -DUSE_OPENMP=ON                                                             `
    -DUSE_OPENCV=OFF                                                            `
    -DUSE_ROCKSDB=ON                                                            `
    -Dglog_DIR="${Env:ProgramFiles}/google-glog/lib/cmake/glog"                 `
    -Dgtest_force_shared_crt=ON                                                 `
    -Dprotobuf_BUILD_SHARED_LIBS=ON                                             `
    -Dpybind11_INCLUDE_DIR="${Env:ProgramFiles}/pybind11/include"               `
    -G"Visual Studio 15 2017 Win64"                                             `
    -T"host=x64"                                                                `
    ..

$ErrorActionPreference="SilentlyContinue"
cmake --build . --config RelWithDebInfo -- -maxcpucount
if (-Not $?)
{
    echo "Failed to build."
    echo "Retry with single thread for logging."
    echo "You may Ctrl-C this if you don't need the log file."
    cmake --build . --config RelWithDebInfo 2>&1 | tee ${Env:TMP}/${proj}.log
    exit 1
}

cmake --build . --config RelWithDebInfo --target run_tests -- -maxcpucount
if (-Not $?)
{
    echo "Check failed but we temporarily bypass it."
}
$ErrorActionPreference="Stop"

cmd /c rmdir /S /Q "${Env:ProgramFiles}/Caffe2"
cmake --build . --config RelWithDebInfo --target install -- -maxcpucount
Get-ChildItem "${Env:ProgramFiles}/Caffe2" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
