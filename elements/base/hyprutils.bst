kind: cmake
description: |
  hyprutils -- Hyprland's C++ utility library

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/pixman.bst

sources:
- kind: tar
  url: github:hyprwm/hyprutils/archive/refs/tags/v0.14.3.tar.gz
  ref: 87bbfc9549ed96316b0d592c16d01f58729b23a2999a5293b73eec620b40c5f5

variables:
  cmake-local: -DBUILD_TESTING=OFF
