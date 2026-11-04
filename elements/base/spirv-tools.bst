kind: cmake
description: |
  SPIRV-Tools -- validates and optimizes SPIR-V, for Mesa's build (the
  Intel drivers' OpenCL kernels).  Static libraries only: nothing at run
  time.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/spirv-headers.bst

sources:
- kind: tar
  url: github:KhronosGroup/SPIRV-Tools/archive/refs/tags/vulkan-sdk-1.4.363.0.tar.gz
  ref: e6c83a215538fbfd265ccf398d3877985055df1273dbed73912bd05307664688

variables:
  cmake-local: >-
    -DSPIRV-Headers_SOURCE_DIR=%{prefix} -DBUILD_SHARED_LIBS=OFF
    -DSPIRV_TOOLS_BUILD_STATIC=ON -DSPIRV_SKIP_TESTS=ON -DSPIRV_WERROR=OFF
