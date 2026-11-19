unpack $src

# After base/llvm.bst, at the version of base/llvm-23.bst.
# LLVM_LIBDIR_SUFFIX: libraries in /usr/lib/$triplet.
# LLVM_DEFAULT_TARGET_TRIPLE: clang then looks for gcc's files and the C
#   library under the same name gcc and glibc were installed with.
# LLVM_TARGETS_TO_BUILD: the two architectures bunix is built for.
# ..._DYLIB: one libLLVM.so and one libclang-cpp.so that every program
#   links, in place of a copy of LLVM in each.
# LLVM_PARALLEL_COMPILE_JOBS, _LINK_JOBS: a compile of LLVM's largest
#   files takes well over a gigabyte of memory, a link several; with
#   one job a processor, a builder with 10 GB ran out.
# CLANG_INSTALL_SCANBUILD, _SCANVIEW: perl and python programs, with parts
#   in /usr/libexec.
# The rest: no optional library, and nothing built that is not installed.
cmake -S llvm -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
    -DLLVM_LIBDIR_SUFFIX=/$triplet -DLLVM_DEFAULT_TARGET_TRIPLE=$triplet \
    -DLLVM_ENABLE_PROJECTS="clang;lld" -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
    -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DCLANG_LINK_CLANG_DYLIB=ON \
    -DLLVM_ENABLE_RTTI=ON -DLLVM_ENABLE_ASSERTIONS=OFF \
    -DLLVM_PARALLEL_COMPILE_JOBS=4 -DLLVM_PARALLEL_LINK_JOBS=2 \
    -DCLANG_INSTALL_SCANBUILD=OFF -DCLANG_INSTALL_SCANVIEW=OFF \
    -DLLVM_ENABLE_ZLIB=FORCE_ON -DLLVM_ENABLE_ZSTD=FORCE_ON \
    -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_LIBEDIT=OFF -DLLVM_ENABLE_LIBPFM=OFF \
    -DLLVM_ENABLE_FFI=OFF -DLLVM_ENABLE_CURL=OFF -DLLVM_ENABLE_HTTPLIB=OFF \
    -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_DOCS=OFF -DCLANG_INCLUDE_TESTS=OFF -DCLANG_INCLUDE_DOCS=OFF
ninja -C build
DESTDIR=$out ninja -C build install

# The python scripts clang installs beside its programs: they would make
# LLVM need python to run.  The last three are scan-build-py, which no
# option leaves out, and which has more in two directories.
rm $out/usr/bin/{git-clang-format,hmaptool,analyze-build,intercept-build,scan-build-py}
rm -r $out/usr/libexec $out/usr/lib/libscanbuild $out/usr/lib/libear
