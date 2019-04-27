# ================================================================
# Compile LLVM
# ================================================================

for i in llvm-{gcc,clang}; do
    [ -e $STAGE/$i ] && ( set -xe
        cd $SCRATCH

        . "$ROOT_DIR/pkgs/utils/git/version.sh" llvm-mirror/llvm,release_
        until git clone --depth 1 -b "$GIT_TAG" "$GIT_REPO"; do sleep 1; echo "Retrying"; done
        cd llvm
        parallel -j0 --bar --line-buffer 'bash -c '"'"'
            set -e
            export PROJ="$(basename "{}")"
            [ "$PROJ" ]
            until git clone --depth 1 -b "'"$GIT_TAG"'" "'"$(sed 's/[^\/]*$//' <<< "$GIT_REPO")"'$PROJ.git" {}; do sleep 1; echo "Retrying"; done
            if [ "$PROJ" = "clang" ]; then
                until git clone --depth 1 -b "'"$GIT_TAG"'" "'"$(sed 's/[^\/]*$//' <<< "$GIT_REPO")"'$PROJ-tools-extra.git" "{}/tools/extra"; do sleep 1; echo "Retrying"; done
            fi
        '"'" ::: projects/{compiler-rt,lib{cxx{,abi},unwind},openmp} tools/{clang,lldb,lld,polly}

        # LLVM repo uses branch instead of tag.
        for i in 'MAJOR' 'MINOR' 'PATCH'; do
            sed -n "s/.*set[[:space:]]*([[:space:]]*LLVM_VERSION_$i[[:space:]][[:space:]]*\([0-9][0-9]*\)[[:space:]]*).*/\1/p" CMakeLists.txt | head -n1
        done | paste -sd. - | xargs git tag

        # ------------------------------------------------------------

        . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

        (
            case "$DISTRO_ID" in
            'centos' | 'fedora' | 'rhel')
                set +xe
                . scl_source enable devtoolset-6
                set -xe
                export CC="gcc" CXX="g++"
                ;;
            'ubuntu')
                export CC="gcc-6" CXX="g++-6"
                ;;
            esac

            mkdir -p build
            cd $_

            # TODO: Enable OpenMP for fortran when ninja supports it.
            export LLVM_COMMON_ARGS="
                -DCLANG_DEFAULT_CXX_STDLIB=libc++
                -DCLANG_ENABLE_PROTO_FUZZER=OFF
                -DCMAKE_BUILD_TYPE=Release
                -DCMAKE_INSTALL_PREFIX='$INSTALL_ABS'
                -DCMAKE_VERBOSE_MAKEFILE=ON
                -DLIBCLANG_BUILD_STATIC=ON
                -DLIBCXX_CONFIGURE_IDE=ON
                -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON
                -DLIBIPT_INCLUDE_PATH='/usr/local/include'
                -DLIBOMP_FORTRAN_MODULES=OFF
                -DLIBOMP_OMPT_SUPPORT=ON
                -DLIBOMP_STATS=OFF
                -DLIBOMP_TSAN_SUPPORT=ON
                -DLIBOMP_USE_HIER_SCHED=ON
                -DLIBOMP_USE_HWLOC=ON
                -DLIBOMP_USE_STDCPPLIB=ON
                -DLIBUNWIND_ENABLE_CROSS_UNWINDING=ON
                -DLLDB_BUILD_INTEL_PT=ON
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
                cmake                                       \
                    -DCMAKE_AR="$(which gcc-ar)"            \
                    -DCMAKE_C_COMPILER="$CC"                \
                    -DCMAKE_CXX_COMPILER="$CXX"             \
                    -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src'"   \
                    -DCMAKE_RANLIB="$(which gcc-ranlib)"    \
                    $LLVM_COMMON_ARGS
            else
                # -DLIBOMPTARGET_NVPTX_ENABLE_BCLIB=ON
                LDFLAGS='-fuse-ld=lld'                  \
                cmake                                   \
                    -DCMAKE_C_COMPILER=clang            \
                    -DCMAKE_CXX_COMPILER=clang++        \
                    -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src'"   \
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
            time cmake --build . --target install -- -k0

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
