# ================================================================
# Compile LLVM
# ================================================================

for i in llvm-{gcc,clang}; do
    [ -e $STAGE/$i ] && ( set -xe
        export LLVM_MIRROR=$GIT_MIRROR/llvm-mirror
        export LLVM_GIT_TAG=release_60

        cd $SCRATCH

        (
            set -e
            echo "Retriving LLVM $LLVM_GIT_TAG..."
            # until git clone --depth 1 --branch "$LLVM_GIT_TAG" "$LLVM_MIRROR/llvm.git"; do echo "Retrying"; done
            until git clone --depth 1 "$LLVM_MIRROR/llvm.git"; do echo "Retrying"; done
            cd llvm
            git checkout $(git tag | sed -n '/^release_[0-9\.]*$/p' | sort -V | tail -n1)
            export LLVM_GIT_TAG="$(git describe --tags)"
            parallel -j0 --bar --line-buffer 'bash -c '"'"'
                set -e
                export PROJ="$(basename "{}")"
                [ "$PROJ" ]
                until git clone --depth 1 --branch $LLVM_GIT_TAG "$LLVM_MIRROR/$PROJ.git" {}; do echo "Retrying"; done
                if [ "$PROJ" = "clang" ]; then
                    until git clone --depth 1 --branch $LLVM_GIT_TAG $LLVM_MIRROR/$PROJ-tools-extra.git "{}/tools/extra"; do echo "Retrying"; done
                fi
            '"'" ::: projects/{compiler-rt,lib{cxx{,abi},unwind},openmp} tools/{clang,lldb,lld,polly}
        )

        cd llvm
        git tag -f '6.0.0'

        # ------------------------------------------------------------

        . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

        (
            set +x
            . scl_source enable devtoolset-7 || true
            set -xe

            mkdir -p build
            cd $_

            # TODO: Enable OpenMP for fortran when ninja supports it.
            export LLVM_COMMON_ARGS="
                -DCLANG_ANALYZER_BUILD_Z3=OFF
                -DCLANG_DEFAULT_CXX_STDLIB=libc++
                -DCMAKE_BUILD_TYPE=Release
                -DCMAKE_INSTALL_PREFIX=\"$INSTALL_ABS\"
                -DCMAKE_VERBOSE_MAKEFILE=ON
                -DLIBCLANG_BUILD_STATIC=ON
                -DLIBCXX_CONFIGURE_IDE=ON
                -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON
                -DLIBOMP_FORTRAN_MODULES=OFF
                -DLIBOMP_OMPT_SUPPORT=ON
                -DLIBOMP_STATS=OFF
                -DLIBOMP_TSAN_SUPPORT=ON
                -DLIBOMP_USE_HWLOC=ON
                -DLIBOMP_USE_STDCPPLIB=ON
                -DLIBUNWIND_ENABLE_CROSS_UNWINDING=ON
                -DLLDB_DISABLE_PYTHON=ON
                -DLLVM_BUILD_LLVM_DYLIB=ON
                -DLLVM_CCACHE_BUILD=ON
                -DLLVM_ENABLE_CXX1Y=ON
                -DLLVM_ENABLE_CXX1Z=ON
                -DLLVM_ENABLE_EH=ON
                -DLLVM_ENABLE_FFI=ON
                -DLLVM_ENABLE_RTTI=ON
                -DLLVM_INSTALL_BINUTILS_SYMLINKS=ON
                -DLLVM_INSTALL_UTILS=ON
                -DLLVM_LINK_LLVM_DYLIB=ON
                -DLLVM_OPTIMIZED_TABLEGEN=ON
                -DPOLLY_ENABLE_GPGPU_CODEGEN=ON
                -G Ninja
                .."
            
            # GCC only takes plugin processed static lib for LTO.
            # Need to use ar/ranlib wrapper.
            #
            # TODO: Enable LTO after fixing "function redeclared as variable" bug in polly.
            if [ $i = llvm-gcc ]; then
                cmake                                   \
                    -DCMAKE_AR=$(which gcc-ar)          \
                    -DCMAKE_RANLIB=$(which gcc-ranlib)  \
                    $LLVM_COMMON_ARGS
            else
                LDFLAGS='-fuse-ld=lld'                  \
                cmake                                   \
                    -DCMAKE_C_COMPILER=clang            \
                    -DCMAKE_CXX_COMPILER=clang++        \
                    -DENABLE_X86_RELAX_RELOCATIONS=ON   \
                    -DLIBCXX_USE_COMPILER_RT=ON         \
                    -DLIBCXXABI_USE_COMPILER_RT=ON      \
                    -DLIBCXXABI_USE_LLVM_UNWINDER=ON    \
                    -DLIBOMP_ENABLE_SHARED=OFF          \
                    -DLIBUNWIND_USE_COMPILER_RT=ON      \
                    -DLLVM_ENABLE_LIBCXX=ON             \
                    -DLLVM_ENABLE_LLD=ON                \
                    -DLLVM_ENABLE_LTO=Thin              \
                    $LLVM_COMMON_ARGS
            fi

            # --------------------------------------------------------

            # time cmake --build . --target dist
            # time cmake --build . --target dist-check
            # time cmake --build . --target rpm
            time cmake --build . --target install
        )

        git tag -f "$(sed 's/[^0-9]//g' <<< "$LLVM_GIT_TAG" | sed 's/\([0-9]\)/\1\./g' | sed 's/\.$//')"
        "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

        cd
        rm -rf $SCRATCH/llvm
    )
    sudo rm -vf $STAGE/$i
    sync || true
done
