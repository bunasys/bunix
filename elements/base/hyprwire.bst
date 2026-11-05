kind: cmake
description: |
  hyprwire -- the IPC wire protocol hyprctl talks to Hyprland with

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst
# its protocol scanner reads XML
- base/pugixml.bst

depends:
- base/hyprutils.bst
- base/libffi.bst

sources:
- kind: tar
  url: github:hyprwm/hyprwire/archive/refs/tags/v0.3.1.tar.gz
  ref: 92a673d40ae6a7d66fbcd0a34ec071e026e17eaeeb0040c3375e4b2a80dba737

variables:
  cmake-local: -DBUILD_TESTING=OFF
