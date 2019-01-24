#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/mirror.ps1" | Out-Null
& "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)/env/toolchain.ps1" | Out-Null

& "${Env:PYTHONHOME}/python.exe" -m pip install -U numpy | Out-Null

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/onnx/onnx.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root= Join-Path "${Env:TMP}" "$proj"

cmd /c rmdir /S /Q "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver='v' + $($(git ls-remote --tags "$repo") -match '.*refs/tags/v[0-9\.]*$' -replace '.*refs/tags/v','' | sort {[Version]$_})[-1]
$latest_ver="master"
git clone --recursive -j100 -b "$latest_ver" "$repo"
pushd "$root"

# ================================================================================
# Update PyBind
# ================================================================================

pushd third_party/pybind11
git fetch --tags
$pybind_latest_ver='v' + $($(git tag) -match '^v[0-9\.]*$' -replace '^v','' | sort {[Version]$_})[-1]
git checkout "$pybind_latest_ver"
git submodule update --init --recursive
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

$onnx_dll="/DONNX_BUILD_MAIN_LIB"
$protobuf_dll="/DPROTOBUF_USE_DLLS"
$dep_dll="${onnx_dll} ${protobuf_dll}"

cmake                                                                           `
    -DBENCHMARK_ENABLE_LTO=ON                                                   `
    -DBUILD_SHARED_LIBS=OFF                                                     `
    -DBUILD_ONNX_PYTHON=OFF                                                     `
    -DCMAKE_C_FLAGS="/MP /Zi /arch:AVX2 ${dep_dll}"                             `
    -DCMAKE_CXX_FLAGS="/EHsc /MP /Zi /arch:AVX2 ${dep_dll}"                     `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"                `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/ONNX"                           `
    -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                                   `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"             `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                             `
    -DONNX_BUILD_BENCHMARKS=ON                                                  `
    -DONNX_BUILD_MAIN_LIB=ON                                                    `
    -DONNX_BUILD_TESTS=OFF                                                      `
    -DONNX_GEN_PB_TYPE_STUBS=ON                                                 `
    -DONNX_ML=ON                                                                `
    -DProtobuf_INCLUDE_DIRS="${Env:ProgramFiles}/protobuf/include"              `
    -DProtobuf_LIBRARY="${Env:ProgramFiles}/protobuf/lib/libprotobuf.lib"       `
    -DProtobuf_PROTOC_EXECUTABLE="${Env:ProgramFiles}/protobuf/bin/protoc.exe"  `
    -G"Ninja"                                                                   `
    ..

cmake --build .
if (-Not $?)
{
    echo "Failed to build."
    echo "Retry with single thread for logging."
    echo "You may Ctrl-C this if you don't need the log file."
    cmake --build . -- -k0
    cmake --build . 2>&1 | tee ${Env:TMP}/${proj}.log
    exit 1
}

$ErrorActionPreference="SilentlyContinue"
# cmake --build . --target test
# if (-Not $?)
# {
#     echo "Check failed but we temporarily bypass it."
# }
$ErrorActionPreference="Stop"

cmd /c rmdir /S /Q "${Env:ProgramFiles}/ONNX"
cmake --build . --target install
cmd /c xcopy /i /f /y "pdb\*.pdb" "${Env:ProgramFiles}\ONNX\lib"
Get-ChildItem "${Env:ProgramFiles}/ONNX" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
