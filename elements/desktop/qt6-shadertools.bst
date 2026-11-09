kind: cmake
description: |
  Qt 6 Shader Tools -- qsb, which compiles the shaders of Qt Quick
  (desktop/qt6-declarative.bst) and Quickshell when they are built.  Its
  glslang and SPIRV-Cross are its own copies.  Build-time only.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- desktop/qt6-base.bst

sources:
- kind: tar
  url: qt:6.12/6.12.0/submodules/qtshadertools-everywhere-src-6.12.0.tar.xz
  ref: c7d84f436e1aaef39fdcadebf2bd71bdf24dc69497e13f2e0198873cbbfea2ab

variables:
  cmake-local: -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF
