# ================================================================
# Compile LLVM
# ================================================================

for i in llvm-{gcc,clang}; do
    [ -e $STAGE/$i ] && ( set -e
        export LLVM_MIRROR=$GIT_MIRROR/llvm-mirror
        export LLVM_GIT_TAG=release_50

        cd $SCRATCH

        ( set -e
            echo "Retriving LLVM "$LLVM_GIT_TAG"..."
            until git clone --branch $LLVM_GIT_TAG $LLVM_MIRROR/llvm.git; do echo 'Retrying'; done
            cd llvm
            cd projects
            for i in compiler-rt lib{cxx{,abi},unwind} openmp; do
                until git clone --branch $LLVM_GIT_TAG $LLVM_MIRROR/$i.git; do echo 'Retrying'; done &
            done
            cd ../tools
            for i in lld lldb polly; do
                until git clone --branch $LLVM_GIT_TAG $LLVM_MIRROR/$i.git; do echo 'Retrying'; done &
            done
            until git clone --branch $LLVM_GIT_TAG $LLVM_MIRROR/clang.git; do echo 'Retrying'; done
            cd clang/tools
            until git clone --branch $LLVM_GIT_TAG $LLVM_MIRROR/clang-tools-extra.git extra; do echo 'Retrying'; done
            wait
        )

        # ------------------------------------------------------------

        mkdir -p llvm/build
        cd $_

        . scl_source enable devtoolset-6
        ccache -C

        export LLVM_COMMON_ARGS="
            -DCLANG_ANALYZER_BUILD_Z3=OFF
            -DCLANG_DEFAULT_CXX_STDLIB=libc++
            -DCMAKE_BUILD_TYPE=Release
            -DCMAKE_INSTALL_PREFIX='\usr\'
            -DCMAKE_VERBOSE_MAKEFILE=ON
            -DLIBCLANG_BUILD_STATIC=ON
            -DLIBCXX_CONFIGURE_IDE=ON
            -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON
            -DLIBOMP_OMPT_SUPPORT=ON
            -DLIBOMP_STATS=OFF
            -DLIBOMP_TSAN_SUPPORT=ON
            -DLIBOMP_USE_HWLOC=ON
            -DLIBOMP_USE_STDCPPLIB=ON
            -DLIBUNWIND_ENABLE_CROSS_UNWINDING=ON
            -DLLDB_DISABLE_PYTHON=ON
            -DLLVM_BUILD_LLVM_DYLIB=ON
            -DLLVM_CCACHE_BUILD=ON
            -DLLVM_ENABLE_EH=ON
            -DLLVM_ENABLE_FFI=ON
            -DLLVM_ENABLE_RTTI=ON
            -DLLVM_INSTALL_UTILS=ON
            -DLLVM_LINK_LLVM_DYLIB=ON
            -DLLVM_OPTIMIZED_TABLEGEN=ON
            -DPOLLY_ENABLE_GPGPU_CODEGEN=ON
            -G Ninja
            .."
        
        if [ $i = llvm-gcc ]; then
            cmake                                   \
                -DLLVM_ENABLE_CXX1Y=ON              \
                $LLVM_COMMON_ARGS
        else
            CC='clang'                              \
            CXX='clang++'                           \
            LD=$(which ld.lld)                      \
            cmake                                   \
                -DENABLE_X86_RELAX_RELOCATIONS=ON   \
                -DLIBCXX_USE_COMPILER_RT=ON         \
                -DLIBCXXABI_USE_COMPILER_RT=ON      \
                -DLIBCXXABI_USE_LLVM_UNWINDER=ON    \
                -DLIBOMP_ENABLE_SHARED=OFF          \
                -DLIBUNWIND_USE_COMPILER_RT=ON      \
                -DLLVM_ENABLE_LIBCXX=ON             \
                -DLLVM_ENABLE_LLD=ON                \
                -DLLVM_ENABLE_LTO=OFF               \
                -DLLVM_ENABLE_CXX1Y=ON              \
                $LLVM_COMMON_ARGS
        fi

        # ------------------------------------------------------------

        # time cmake --build . --target dist
        # time cmake --build . --target dist-check
        # time cmake --build . --target rpm
        time cmake --build . --target install

        ldconfig &
        ccache -C &
        cd
        rm -rf $SCRATCH/llvm
        wait
    ) && rm -rvf $STAGE/$i
    sync || true
done
