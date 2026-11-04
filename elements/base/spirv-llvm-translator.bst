kind: cmake
description: |
  SPIRV-LLVM-Translator -- turns LLVM IR into SPIR-V: how Mesa's build
  compiles OpenCL C (the Intel drivers' kernels).  A static library, used
  only at build time.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst
- base/llvm.bst
- base/spirv-headers.bst

sources:
- kind: tar
  url: github:KhronosGroup/SPIRV-LLVM-Translator/archive/refs/tags/v22.1.8.tar.gz
  ref: 895bca0285fd4118800912a54527c0ae0d0c6e62591e807c3c96c6b342c4c5e2

variables:
  cmake-local: >-
    -DLLVM_DIR=%{libdir}/cmake/llvm -DBUILD_SHARED_LIBS=OFF
    -DLLVM_EXTERNAL_SPIRV_HEADERS_SOURCE_DIR=%{prefix} -DLLVM_SPIRV_INCLUDE_TESTS=OFF
