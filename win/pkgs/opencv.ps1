#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

. "$PSScriptRoot/env/mirror.ps1"
. "$PSScriptRoot/env/toolchain.ps1"

pushd ${Env:TMP}
$repo="${Env:GIT_MIRROR}/opencv/opencv.git"
$proj="$($repo -replace '.*/','' -replace '.git$','')"
$root="${Env:TMP}/$proj"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "$root"
if (Test-Path "$root")
{
    echo "Failed to remove `"$root`""
    Exit 1
}

$latest_ver=$($(git ls-remote --tags "$repo") -match '.*refs/tags/[0-9\.]*$' -replace '.*refs/tags/','' | sort {[Version]$_})[-1]
git clone -b "$latest_ver" -j8 "$repo"
pushd "$root"

# Fix B/W TIFF: https://github.com/opencv/opencv/pull/17275
git cherry-pick 4e97c697

# ------------------------------------------------------------

git submodule add "../opencv_contrib.git" contrib
pushd contrib
git checkout "$latest_ver"
popd
git commit -am "Add opencv_contrib as submodule"

# ------------------------------------------------------------

mkdir build
pushd build

# Copy MKL's environment variables from ".bat" file to PowerShell.
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 lp64 vs2017 & set") -Match '^MKL(_|ROOT)' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 lp64 vs2017 & set") -Match '^LIB' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 lp64 vs2017 & set") -Match '^CPATH' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)
Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/mkl/bin/mklvars.bat`" intel64 lp64 vs2017 & set") -Match '^INCLUDE' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)

# Copy TBB's environment variables from ".bat" file to PowerShell.
# Invoke-Expression $($(cmd /C "`"${Env:ProgramFiles(x86)}/IntelSWTools/compilers_and_libraries/windows/tbb/bin/tbbvars.bat`" intel64 vs2015 & env") -Match '^TBB(_|ROOT)' -Replace '^','${Env:' -Replace '=','}="' -Replace '$','"' | Out-String)

# - Only "Release" and "Debug" are supported.
#   Use "BUILD_WITH_DEBUG_INFO" for "RelWithDebInfo".
# - Starting from 4.1.1, OpenCV FreeType module changes to ocv_check_modules() with ony pkg-config support.
#   <PKG>_LIBRARIES is be overwritten in this approach.
#   Use <PKG>_LINK_LIBRARIES and <PKG>_LINK_LIBRARIES_XXXXX to help with injection according to:
#     * https://github.com/opencv/opencv/blob/01b2c5a77ca6dbef3baef24ebc0a5984579231d9/cmake/OpenCVUtils.cmake#L823-L825
cmake                                                                   `
    -DBUILD_PROTOBUF=OFF                                                `
    -DBUILD_SHARED_LIBS=ON                                              `
    -DBUILD_WITH_DEBUG_INFO=ON                                          `
    -DBUILD_WITH_STATIC_CRT=OFF                                         `
    -DBUILD_opencv_world=OFF                                            `
    -DBUILD_opencv_dnn=OFF                                              `
    -DCMAKE_BUILD_TYPE=Release                                          `
    -DCMAKE_C_FLAGS="/MP /Zi /arch:AVX2 "                               `
    -DCMAKE_CXX_FLAGS="/EHsc /MP /Zi /arch:AVX2 "                       `
    -DCMAKE_EXE_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"        `
    -DCMAKE_INSTALL_PREFIX="${Env:ProgramFiles}/opencv"                 `
    -DCMAKE_PDB_OUTPUT_DIRECTORY="${PWD}/pdb"                           `
    -DCMAKE_SHARED_LINKER_FLAGS="/DEBUG:FASTLINK /LTCG:incremental"     `
    -DCMAKE_STATIC_LINKER_FLAGS="/LTCG:incremental"                     `
    -DCPU_BASELINE=AVX                                                  `
    -DCPU_DISPATCH='FP16;AVX2'                                          `
    -DCUDA_NVCC_FLAGS='--expt-relaxed-constexpr'                        `
    -DCUDA_SEPARABLE_COMPILATION=OFF                                    `
    -DEIGEN_INCLUDE_PATH="${Env:ProgramFiles}/Eigen3/include/eigen3"    `
    -DENABLE_CXX11=ON                                                   `
    -DENABLE_LTO=ON                                                     `
    -DENABLE_PRECOMPILED_HEADERS=ON                                     `
    -DFREETYPE_FOUND=ON                                                 `
    -DFREETYPE_INCLUDE_DIRS="$(${Env:ProgramFiles} -replace '\\','/')/freetype/include/freetype2"   `
    -DFREETYPE_LIBRARIES="$(${Env:ProgramFiles} -replace '\\','/')/freetype/lib/freetype.lib"       `
    -DFREETYPE_LINK_LIBRARIES="$(${Env:ProgramFiles} -replace '\\','/')/freetype/lib/freetype.lib"  `
    -DFREETYPE_LINK_LIBRARIES_XXXXX=ON                                  `
    -DHARFBUZZ_FOUND=ON                                                 `
    -DHARFBUZZ_INCLUDE_DIRS="$(${Env:ProgramFiles} -replace '\\','/')/harfbuzz/include/harfbuzz"    `
    -DHARFBUZZ_LIBRARIES="$(${Env:ProgramFiles} -replace '\\','/')/harfbuzz/lib/harfbuzz.lib"       `
    -DHARFBUZZ_LINK_LIBRARIES="$(${Env:ProgramFiles} -replace '\\','/')/harfbuzz/lib/harfbuzz.lib"  `
    -DHARFBUZZ_LINK_LIBRARIES_XXXXX=ON                                  `
    -DINSTALL_CREATE_DISTRIB=OFF                                        `
    -DINSTALL_TESTS=ON                                                  `
    -DMKL_WITH_OPENMP=ON                                                `
    -DOPENCV_ENABLE_NONFREE=OFF                                         `
    -DOPENCV_EXTRA_MODULES_PATH='../contrib/modules'                    `
    -DOpenGL_GL_PREFERENCE=GLVND                                        `
    -DPROTOBUF_UPDATE_FILES=ON                                          `
    -DWITH_CUDA=OFF                                                     `
    -DWITH_HALIDE=OFF                                                   `
    -DWITH_MKL=ON                                                       `
    -DWITH_NVCUVID=ON                                                   `
    -DWITH_OPENGL=ON                                                    `
    -DWITH_OPENMP=ON                                                    `
    -DWITH_QT=OFF                                                       `
    -DWITH_TBB=OFF                                                      `
    -DWITH_VULKAN=ON                                                    `
    -G"Ninja"                                                           `
    ..

cmake --build .
if (-Not $?)
{
    echo "Failed to build."
    echo "Retry with best-effort for logging."
    echo "You may Ctrl-C this if you don't need the log file."
    cmake --build . -- -k0
    cmake --build . 2>&1 | tee ${Env:TMP}/${proj}.log
    exit 1
}

$ErrorActionPreference="SilentlyContinue"
# ctest -j ${Env:NUMBER_OF_PROCESSORS}
# if (-Not $?)
# {
#     echo "Check failed but we temporarily bypass it."
# }
$ErrorActionPreference="Stop"

rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${Env:ProgramFiles}/opencv"
cmake --build . --target install
cmd /c xcopy /i /f /y "pdb\*.pdb" "${Env:ProgramFiles}\opencv\x64\vc16\bin"
Get-ChildItem "${Env:ProgramFiles}/opencv" -Filter *.dll -Recurse | Foreach-Object { New-Item -Force -ItemType SymbolicLink -Path "${Env:SystemRoot}\System32\$_" -Value $_.FullName }

popd
popd
rm -Force -Recurse "$root"
popd
