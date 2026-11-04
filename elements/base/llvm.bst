kind: cmake
description: |
  LLVM, clang and lld, for building Mesa and Zig: llvmpipe (rendering on
  the CPU) and radeonsi compile shaders with libLLVM at run time; Mesa's
  build compiles the Intel drivers' OpenCL kernels with clang; Zig (which
  Ghostty is written in) is built on all three.  LLVM 22: the version Zig
  0.17 is made for.  All of LLVM's default targets, which Zig requires.
  The running system gets libLLVM alone (base/llvm-libs.bst); the rest are
  build tools.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst

depends:
- base/zlib.bst
- base/zstd.bst

sources:
- kind: tar
  url: github:llvm/llvm-project/releases/download/llvmorg-22.1.8/llvm-project-22.1.8.src.tar.xz
  ref: 922f1817a0df7b1489272d18134ee0087a8b068828f87ac63b9861b1a9965888

variables:
  conf-root: "%{build-root}/llvm"
  # LLVM accepts only its own build types, not the project's None
  cmake-global: -DCMAKE_BUILD_TYPE=Release
  # One shared libLLVM that every tool and Mesa link (and libclang-cpp
  # likewise).  Linking it takes a few GB of memory: two links at a time.
  # LLVM puts libraries in lib$LLVM_LIBDIR_SUFFIX, ignoring
  # CMAKE_INSTALL_LIBDIR: the suffix gives UAPI.9's multiarch directory.
  # Assertions off: LLVM turns them on for any build type but Release.
  cmake-local: >-
    -DLLVM_ENABLE_PROJECTS="clang;lld"
    -DLLVM_LIBDIR_SUFFIX=/%{triplet}
    -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DCLANG_LINK_CLANG_DYLIB=ON
    -DLLVM_ENABLE_RTTI=ON -DLLVM_ENABLE_ASSERTIONS=OFF -DLLVM_PARALLEL_LINK_JOBS=2
    -DLLVM_ENABLE_ZLIB=FORCE_ON -DLLVM_ENABLE_ZSTD=FORCE_ON
    -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_LIBEDIT=OFF -DLLVM_ENABLE_LIBPFM=OFF
    -DLLVM_ENABLE_FFI=OFF -DLLVM_ENABLE_CURL=OFF -DLLVM_ENABLE_HTTPLIB=OFF
    -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF
    -DLLVM_INCLUDE_DOCS=OFF -DCLANG_INCLUDE_TESTS=OFF -DCLANG_INCLUDE_DOCS=OFF
