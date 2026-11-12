kind: cmake
description: |
  LLVM 23, clang, lld and compiler-rt -- only for building Hudhud
  (docs/browser.md).  Chromium follows LLVM's development branch and
  needs a newer clang than the system's LLVM 22 (base/llvm.bst), which
  Mesa and Zig are pinned to.  Installed in its own prefix,
  /usr/lib/llvm-23, so the two never meet.

  compiler-rt: Chromium links clang's runtime libraries itself --
  clang_rt.builtins (math intrinsics that must win over Rust's) and
  clang_rt.profile (for its Rust code) -- from clang's resource directory.
  Only those two are built.

  Not on the running system.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/python.bst

depends:
- base/zlib.bst
- base/zstd.bst

sources:
- kind: tar
  url: github:llvm/llvm-project/releases/download/llvmorg-23.1.5/llvm-project-23.1.5.src.tar.xz
  ref: fb50b1eac93ddeb3aa8dab4cfe324dff74f4a9c2bdee6160c9e36188f8d06a6e

environment:
  # Built on the Fly machine's 16 CPUs (tools/fly/README.md); a constant
  # here, so the cache key does not depend on the host
  JOBS: -j16

variables:
  conf-root: "%{build-root}/llvm"
  # LLVM accepts only its own build types, not the project's None
  cmake-global: -DCMAKE_BUILD_TYPE=Release
  # Static libraries: the tools stand alone in their prefix.  Only the
  # x86 back end: Chromium builds for x86-64 alone.
  cmake-local: >-
    -DCMAKE_INSTALL_PREFIX=/usr/lib/llvm-23
    -DLLVM_ENABLE_PROJECTS="clang;lld"
    -DLLVM_ENABLE_RUNTIMES=compiler-rt
    -DLLVM_TARGETS_TO_BUILD=X86
    -DLLVM_ENABLE_ASSERTIONS=OFF -DLLVM_PARALLEL_LINK_JOBS=4
    -DLLVM_ENABLE_ZLIB=FORCE_ON -DLLVM_ENABLE_ZSTD=FORCE_ON
    -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_LIBEDIT=OFF -DLLVM_ENABLE_LIBPFM=OFF
    -DLLVM_ENABLE_FFI=OFF -DLLVM_ENABLE_CURL=OFF -DLLVM_ENABLE_HTTPLIB=OFF
    -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF
    -DLLVM_INCLUDE_DOCS=OFF -DCLANG_INCLUDE_TESTS=OFF -DCLANG_INCLUDE_DOCS=OFF
    -DCOMPILER_RT_BUILD_BUILTINS=ON -DCOMPILER_RT_BUILD_PROFILE=ON
    -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF
    -DCOMPILER_RT_BUILD_LIBFUZZER=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF
    -DCOMPILER_RT_BUILD_ORC=OFF -DCOMPILER_RT_BUILD_CTX_PROFILE=OFF
    -DCOMPILER_RT_BUILD_GWP_ASAN=OFF

config:
  install-commands:
    (>):
    # the two runtime libraries, where Chromium looks for them
    - |
      rt=%{install-root}/usr/lib/llvm-23/lib/clang/23/lib/x86_64-unknown-linux-gnu
      ls -l $rt/libclang_rt.builtins.a $rt/libclang_rt.profile.a
