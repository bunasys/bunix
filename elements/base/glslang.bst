kind: cmake
description: |
  glslang -- compiles GLSL shaders to SPIR-V (Hyprland's shaders).  Without
  the SPIR-V optimizer and the command-line tools.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: github:KhronosGroup/glslang/archive/refs/tags/16.6.0.tar.gz
  ref: 9c09b901149c729df745057dafa815278aaa101b84d2b6e14f16a42de52f97f2

variables:
  cmake-local: -DBUILD_SHARED_LIBS=ON -DENABLE_OPT=OFF -DGLSLANG_TESTS=OFF -DBUILD_EXTERNAL=OFF -DENABLE_GLSLANG_BINARIES=OFF
