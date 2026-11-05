kind: cmake
description: |
  hyprgraphics -- image loading and colour management for Hyprland: PNG,
  JPEG, WebP and SVG wallpapers and icons.  Without JPEG XL and HEIF.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/cairo.bst
- base/file.bst
- base/hyprutils.bst
- base/libdrm.bst
- base/libjpeg-turbo.bst
- base/libpng.bst
- base/librsvg.bst
- base/libwebp.bst
- base/mesa.bst
- base/pango.bst
- base/pixman.bst

sources:
- kind: tar
  url: github:hyprwm/hyprgraphics/archive/refs/tags/v0.6.0.tar.gz
  ref: 27e9e19ff59ba75a2963d72c3dcb5c0840b266b90d7fca6d5df7cac105419b08

variables:
  cmake-local: -DBUILD_TESTING=OFF
