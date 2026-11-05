kind: cmake
description: |
  hyprcursor -- Hyprland's cursor theme format: SVG or PNG cursors in a zip,
  scaled to any size; and hyprcursor-util, which makes such themes

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/cairo.bst
- base/hyprlang.bst
- base/librsvg.bst
- base/libzip.bst
# a shared library, not headers only: needed at run time
- base/tomlplusplus.bst

sources:
- kind: tar
  url: github:hyprwm/hyprcursor/archive/refs/tags/v0.1.13.tar.gz
  ref: 82af8b2ce27242ffdd6baebaa71b3f6c8665dc25c52bfcfccc16912622896af8

variables:
  cmake-local: -DBUILD_TESTING=OFF
