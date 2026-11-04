kind: cmake
description: |
  SPIR-V Headers -- the SPIR-V grammar and headers (SPIRV-Tools, Mesa).
  The commit base/spirv-llvm-translator.bst names in its
  spirv-headers-tag.conf: the translator uses the newest opcodes.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst

sources:
- kind: tar
  url: github:KhronosGroup/SPIRV-Headers/archive/cb42dec3830d3ac67fa449ecdc0c0f73d5e74498.tar.gz
  ref: 117010e525fe36b1ce006e0e58a6e0a3b415aabc9179d912b92737f41f3f994f
