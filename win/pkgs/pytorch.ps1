#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

& "${Env:PYTHONHOME}/python.exe" -m pip install -U numpy pyyaml | Out-Null

pushd ${Env:SCRATCH}
$repo="${Env:GIT_MIRROR}/pytorch/pytorch.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root= Join-Path "${Env:SCRATCH}" "$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

git clone --recursive -j100 "$repo"
pushd "$root"

# ================================================================================
# Patch
# ================================================================================

git remote add patch https://github.com/xkszltl/pytorch.git
git fetch patch
git pull patch lstm

if (-Not $?)
{
    echo "Failed to patch Caffe2"
    exit 1
}

# ================================================================================
# Protobuf Patch for CUDA
#   - https://github.com/pytorch/pytorch/issues/42939
# ================================================================================

git remote add peterjc123 https://github.com/peterjc123/pytorch.git
git pull peterjc123 nvcc_flag_cleanup
git pull peterjc123 system_protobuf_patch

if (-Not $?)
{
    echo "Failed to apply protobuf patch for CUDA build."
    exit 1
}

# ================================================================================
# Patch DNNL compat_lib
#   - https://github.com/pytorch/pytorch/issues/42115
# ================================================================================

pushd third_party/ideep
pushd mkl-dnn
git cherry-pick -X theirs 2bc4d3c
popd
git --no-pager diff
git commit -am 'Patch DNNL compat_libs.'
popd
git --no-pager diff
git commit -am 'Patch DNNL compat_libs.'

# ================================================================================
# Update Protobuf
# ================================================================================

pushd third_party/protobuf
git fetch --tags
$pb_latest_ver='v' + $($(git tag) -match '^v[0-9\.]*$' -replace '^v','' | sort {[Version]$_})[-1]
git checkout "$pb_latest_ver"
git remote add patch https://github.com/xkszltl/protobuf.git
git fetch patch
# git cherry-pick patch/constexpr-3.7
git submodule update --init
popd

# ================================================================================
# Update ONNX
# ================================================================================

pushd third_party/onnx
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
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 lp64 vs2017 & set") -Match '^MKL(_|ROOT)' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 lp64 vs2017 & set") -Match '^LIB' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 lp64 vs2017 & set") -Match '^CPATH' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 lp64 vs2017 & set") -Match '^INCLUDE' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)

$gtest_silent_warning   = "/D_SILENCE_STDEXT_HASH_DEPRECATION_WARNINGS /D_SILENCE_TR1_NAMESPACE_DEPRECATION_WARNING /w"
$gflags_dll             = "/DGFLAGS_IS_A_DLL=1"
$protobuf_dll           = "/DPROTOBUF_USE_DLLS"
$dep_dll                = "${gflags_dll} ${protobuf_dll}"
$mkldnn_win             = "/DWIN32"
$cflags                 = "${dep_dll} ${mkldnn_win}"
$cxxflags               = "${cflags} ${gtest_silent_warning}"

# ==========================================================================================
# Known issues:
#   * They claim (I think it's wrong) that MKL-DNN requires OpenMP 3.0 which is not supported in MSVC.
#   * Fix CUDA compilation with /FS.
#   * CUDA separable compilation with ninja creates long command not runnable.
#     https://github.com/pytorch/pytorch/issues/44599
#   * /Zi is replaced by /Z7 in CMake.
#   * Need to run config multiple times before getting consistent output.
#     https://github.com/pytorch/pytorch/issues/44614
# ==========================================================================================
For ($i=0; $i -lt 2; ++$i)
{
    cmake                                                                           `
        -DBLAS=MKL                                                                  `
        -DBUILD_BINARY=ON                                                           `
        -DBUILD_CUSTOM_PROTOBUF=OFF                                                 `
        -DBUILD_PYTHON=ON                                                           `
        -DBUILD_SHARED_LIBS=ON                                                      `
        -DBUILD_TEST=ON                                                             `
        -DCMAKE_BUILD_TYPE=Release                                                  `
        -DCMAKE_C_FLAGS="/FS /GL /MP /Zi /arch:AVX2 ${cflags}"                      `
        -DCMAKE_CUDA_SEPARABLE_COMPILATION=OFF                                      `
        -DCMAKE_CXX_FLAGS="/EHsc /FS /GL /MP /Zi /arch:AVX2 ${cxxflags}"            `
        -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"                `
        -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/Caffe2"                         `
        -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                                   `
        -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"             `
        -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                             `
        -DCMAKE_VERBOSE_MAKEFILE=ON                                                 `
        -DCPUINFO_BUILD_TOOLS=ON                                                    `
        -DCUDA_NVCC_FLAGS="--expt-relaxed-constexpr"                                `
        -DCUDA_SEPARABLE_COMPILATION=OFF                                            `
        -DCUDA_VERBOSE_BUILD=ON                                                     `
        -DDNNL_LIBRARY_TYPE="SHARED"                                                `
        -DMKLDNN_LIBRARY_TYPE="SHARED"                                              `
        -DPROTOBUF_INCLUDE_DIRS="${Env:ProgramFiles}/protobuf/include"              `
        -DPROTOBUF_LIBRARIES="${Env:ProgramFiles}/protobuf/bin"                     `
        -DPROTOBUF_PROTOC_EXECUTABLE="${Env:ProgramFiles}/protobuf/bin/protoc.exe"  `
        -DTORCH_CUDA_ARCH_LIST="Kepler;Maxwell;Pascal;Volta"                        `
        -DUSE_CUDA=OFF                                                              `
        -DUSE_DISTRIBUTED=OFF                                                       `
        -DUSE_GFLAGS=ON                                                             `
        -DUSE_GLOG=ON                                                               `
        -DUSE_GLOO=OFF                                                              `
        -DUSE_FBGEMM=ON                                                             `
        -DUSE_LEVELDB=OFF                                                           `
        -DUSE_LMDB=OFF                                                              `
        -DUSE_METAL=OFF                                                             `
        -DUSE_MKLDNN=ON                                                             `
        -DUSE_MPI=OFF                                                               `
        -DUSE_NCCL=ON                                                               `
        -DUSE_NNPACK=OFF                                                            `
        -DUSE_NUMA=OFF                                                              `
        -DUSE_OBSERVERS=ON                                                          `
        -DUSE_OPENMP=ON                                                             `
        -DUSE_OPENCV=ON                                                             `
        -DUSE_ROCKSDB=ON                                                            `
        -Dglog_DIR="${Env:ProgramFiles}/google-glog/lib/cmake/glog"                 `
        -Dgtest_force_shared_crt=ON                                                 `
        -Dpybind11_INCLUDE_DIR="${Env:ProgramFiles}/pybind11/include"               `
        -G"Ninja"                                                                   `
        ..
}
cmake --build . --target rebuild_cache

$ErrorActionPreference="SilentlyContinue"
cmake --build .
if (-Not $?)
{
    echo "Failed to build."
    echo "Retry with best-effort for logging."
    echo "You may Ctrl-C this if you don't need the log file."
    cmake --build . -- -k0
    cmake --build . 2>&1 | tee ${Env:SCRATCH}/${proj}.log
    exit 1
}

cmake --build . --target test
if (-Not $?)
{
    echo "[Warning] Check failed but we temporarily bypass it. Some tests are expected to fail on Windows."
}
$ErrorActionPreference="Stop"

cmd /c rmdir /S /Q "${Env:ProgramFiles}/Caffe2"
cmd /c rmdir /S /Q "${Env:ProgramFiles}/torch"
cmake --build . --target install
cmd /c xcopy /e /i /f /y "${Env:ProgramFiles}\torch" "${Env:ProgramFiles}\Caffe2\include\torch"
cmd /c rmdir /S /Q "${Env:ProgramFiles}/torch"
# cmd /c xcopy    /i /f /y "pdb\*.pdb" "${Env:ProgramFiles}\Caffe2\lib"
Get-ChildItem "${Env:ProgramFiles}/Caffe2" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
