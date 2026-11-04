kind: cmake
description: |
  Zig 0.17, the compiler Ghostty is written in -- a build tool, like
  clang: it builds Ghostty and is not part of the system.  Built from
  source on LLVM 22 (base/llvm.bst), linking its shared libLLVM and
  libclang-cpp; for any x86-64 CPU, not just the build machine's.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst

depends:
- base/llvm.bst
- base/zlib.bst
- base/zstd.bst

sources:
- kind: tar
  url: https://ziglang.org/download/0.17.1/zig-0.17.1.tar.xz
  ref: 1e89bf06610b769a8c77676c6c8d54b093a0db60f4891f2f91014829012f0e24

variables:
  cmake-local: >-
    -DZIG_VERSION=0.17.1 -DZIG_SHARED_LLVM=ON -DZIG_TARGET_MCPU=baseline
    -DZIG_USE_LLVM_CONFIG=ON
