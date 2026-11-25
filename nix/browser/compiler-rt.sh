unpack $src
# compiler-rt alone, against the system's LLVM and compiled by its clang,
# into that clang's resource directory (/usr/lib/$triplet/clang/<major>),
# one directory a target.  Only the builtins and the profile runtime:
# what Chromium links.
major=$(llvm-config --version | cut -d. -f1)
resource_dir=/usr/lib/$triplet/clang/$major
[ -d $resource_dir ]
# clang's own name for the target (x86_64-unknown-linux-gnu), which its
# per-target directory is named after
target=$(clang -print-target-triple)
cmake -S compiler-rt -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
    -DCOMPILER_RT_STANDALONE_BUILD=ON -DLLVM_CONFIG_PATH=/usr/bin/llvm-config \
    -DCOMPILER_RT_INSTALL_PATH=$resource_dir -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
    -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON -DCMAKE_C_COMPILER_TARGET=$target \
    -DCOMPILER_RT_BUILD_BUILTINS=ON -DCOMPILER_RT_BUILD_PROFILE=ON \
    -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF \
    -DCOMPILER_RT_BUILD_LIBFUZZER=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF \
    -DCOMPILER_RT_BUILD_ORC=OFF -DCOMPILER_RT_BUILD_CTX_PROFILE=OFF \
    -DCOMPILER_RT_BUILD_GWP_ASAN=OFF -DCOMPILER_RT_INCLUDE_TESTS=OFF
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install
# what Chromium links, where clang looks for it
ls $out$resource_dir/lib/*/libclang_rt.builtins.a $out$resource_dir/lib/*/libclang_rt.profile.a
