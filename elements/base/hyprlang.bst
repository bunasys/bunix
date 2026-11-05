kind: cmake
description: |
  hyprlang -- Hyprland's configuration language

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/hyprutils.bst

sources:
- kind: tar
  url: github:hyprwm/hyprlang/archive/refs/tags/v0.6.8.tar.gz
  ref: d10a0778b646e04d83e8b90cc0f764fb96958c01a15c3c0678d95a40fc647ed5

variables:
  cmake-local: -DBUILD_TESTING=OFF
