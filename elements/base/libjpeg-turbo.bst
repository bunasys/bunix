kind: cmake
description: |
  libjpeg-turbo -- JPEG images (gdk-pixbuf, Hyprland's wallpapers and
  screenshots).  Without its SIMD code for now, which needs the NASM
  assembler.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: github:libjpeg-turbo/libjpeg-turbo/releases/download/3.2.1/libjpeg-turbo-3.2.1.tar.gz
  ref: c27ad72a68da151177929aa969ae773a2da5ac2af9ce946079314fdac8cece7f

variables:
  cmake-local: -DENABLE_STATIC=OFF -DWITH_SIMD=OFF -DWITH_TURBOJPEG=ON
