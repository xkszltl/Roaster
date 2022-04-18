# ================================================================
# Compile LLVM
# ================================================================

for i in llvm-{gcc,clang}; do
    [ -e $STAGE/$i ] && ( set -xe
        cd $SCRATCH

        . "$ROOT_DIR/pkgs/utils/git/version.sh" llvm/llvm-project,llvmorg-14.
        until git clone --depth 1 -b "$GIT_TAG" "$GIT_REPO" llvm; do sleep 1; echo "Retrying"; done
        cd llvm

        # ------------------------------------------------------------

        . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

        (
            . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
            . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

            mkdir -p build
            cd $_

            # TODO: Enable OpenMP for fortran when ninja supports it.
            # Known issues:
            #   - Enable LLVM_LIBC_ENABLE_LINTING to bypass libc system header check failures.
            #     https://github.com/llvm/llvm-project/blob/176249bd6732a8044d457092ed932768724a6f06/libc/test/src/CMakeLists.txt#L77
            #   - OpenMP in LLVM 14 requires hwloc 2, not available on CentOS 7.
            export LLVM_COMMON_ARGS="
                -DCLANG_DEFAULT_CXX_STDLIB=libc++
                -DCLANG_DEFAULT_LINKER=lld
                -DCLANG_DEFAULT_OBJCOPY=llvm-objcopy
                -DCLANG_DEFAULT_OPENMP_RUNTIME=libomp
                -DCLANG_DEFAULT_RTLIB=libgcc
                -DCLANG_ENABLE_PROTO_FUZZER=OFF
                -DCLANG_OPENMP_NVPTX_DEFAULT_ARCH='sm_61'
                -DCMAKE_BUILD_TYPE=Release
                -DCMAKE_INSTALL_PREFIX='$INSTALL_ABS'
                -DCMAKE_VERBOSE_MAKEFILE=ON
                -DENABLE_LINKER_BUILD_ID=ON
                -DLIBCLANG_BUILD_STATIC=ON
                -DLIBCXX_CONFIGURE_IDE=ON
                -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON
                -DLIBIPT_INCLUDE_PATH='/usr/local/include'
                -DLIBOMP_ENABLE_SHARED=ON
                -DLIBOMP_FORTRAN_MODULES=OFF
                -DLIBOMP_INSTALL_ALIASES=OFF
                -DLIBOMP_OMPT_SUPPORT=ON
                -DLIBOMP_STATS=OFF
                -DLIBOMP_TSAN_SUPPORT=ON
                -DLIBOMP_USE_HIER_SCHED=ON
                -DLIBOMP_USE_HWLOC=$([ "$(hwloc-info --version | sed 's/.*[[:space:]]//' | cut -d. -f1)" -ge 2 ] && echo 'ON' || echo 'OFF')
                -DLIBOMP_USE_STDCPPLIB=ON
                -DLIBOMPTARGET_NVPTX_COMPUTE_CAPABILITIES='35,37,52,60,61,70,75,80'
                -DLIBUNWIND_ENABLE_CROSS_UNWINDING=ON
                -DLLDB_BUILD_INTEL_PT=ON
                -DLLDB_ENABLE_PYTHON=OFF
                -DLLVM_BUILD_LLVM_DYLIB=ON
                -DLLVM_CCACHE_BUILD=ON
                -DLLVM_ENABLE_ASSERTIONS=ON
                -DLLVM_ENABLE_EH=ON
                -DLLVM_ENABLE_FFI=ON
                -DLLVM_ENABLE_RTTI=ON
                -DLLVM_INSTALL_BINUTILS_SYMLINKS=ON
                -DLLVM_INSTALL_UTILS=ON
                -DLLVM_LIBC_ENABLE_LINTING=OFF
                -DLLVM_LINK_LLVM_DYLIB=ON
                -DLLVM_OPTIMIZED_TABLEGEN=ON
                -DLLVM_USE_PERF=ON
                -DPOLLY_ENABLE_GPGPU_CODEGEN=ON
                -G Ninja
                ../llvm"

            if [ $i = llvm-gcc ]; then
                # Known issues:
                #   - GCC only takes plugin-processed static lib for LTO.
                #     Need to use ar/ranlib wrapper.
                #   - GCC LTO is too slow.
                #   - libcxx in LLVM 14 requires gcc 11 to build.
                #   - Parallel STL does not have runtime build in LLVM 14.
                cmake                                       \
                    -DCMAKE_AR="$(which gcc-ar)"            \
                    -DCMAKE_C_COMPILER="$CC"                \
                    -DCMAKE_CXX_COMPILER="$CXX"             \
                    -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src'"              \
                    -DCMAKE_RANLIB="$(which gcc-ranlib)"    \
                    -DGCC_INSTALL_PREFIX="$(realpath -e "$(dirname "$(realpath -e "$(which "$CC")")")/..")" \
                    -DLIBCXX_ENABLE_PARALLEL_ALGORITHMS=OFF \
                    -DLLVM_ENABLE_LTO=OFF                   \
                    -DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra;compiler-rt;libclc;libunwind;lld;lldb;openmp;polly;pstl'    \
                    -DLLVM_ENABLE_RUNTIMES='libcxx;libcxxabi'   \
                    $LLVM_COMMON_ARGS
            else
                cmake                                       \
                    -DCMAKE_C_COMPILER=clang                \
                    -DCMAKE_CXX_COMPILER=clang++            \
                    -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src'"  \
                    -DCMAKE_{EXE,SHARED}_LINKER_FLAGS="-fuse-ld=lld"                            \
                    -DENABLE_X86_RELAX_RELOCATIONS=ON       \
                    -DLIBCXX_ENABLE_PARALLEL_ALGORITHMS=ON  \
                    -DLIBCXX_USE_COMPILER_RT=ON             \
                    -DLIBCXXABI_USE_COMPILER_RT=ON          \
                    -DLIBCXXABI_USE_LLVM_UNWINDER=ON        \
                    -DLIBOMPTARGET_NVPTX_ENABLE_BCLIB=ON    \
                    -DLIBUNWIND_USE_COMPILER_RT=ON          \
                    -DLLVM_ENABLE_LIBCXX=ON                 \
                    -DLLVM_ENABLE_LLD=ON                    \
                    -DLLVM_ENABLE_LTO=Thin                  \
                    -DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra;compiler-rt;libc;libclc;libcxx;libcxxabi;libunwind;lld;lldb;mlir;polly;pstl'    \
                    -DLLVM_ENABLE_RUNTIMES='openmp'         \
                    -DLLVM_TOOL_MLIR_BUILD=ON               \
                    $LLVM_COMMON_ARGS
            fi

            # --------------------------------------------------------

            # time cmake --build . --target dist
            # time cmake --build . --target dist-check
            # time cmake --build . --target rpm
            time cmake --build . --target install -- -k0 || cmake --build . --target install -- -j1

            # Avoid shadowing gcc stack.
            rm -f "$INSTALL_ABS/bin/"{ar,nm,ranlib}
        )

        "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

        cd
        rm -rf $SCRATCH/llvm
    )
    sudo rm -vf $STAGE/$i
    sync || true
done
