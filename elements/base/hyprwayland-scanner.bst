kind: cmake
description: |
  hyprwayland-scanner -- generates C++ bindings from Wayland protocol XML
  (aquamarine and Hyprland build with it)

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/pugixml.bst

sources:
- kind: tar
  url: github:hyprwm/hyprwayland-scanner/archive/refs/tags/v0.4.6.tar.gz
  ref: 05f55fd1a20d8ca81b5030980fdb7c87147749230145bdb3745af2741d617f5c
