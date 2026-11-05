kind: cmake
description: |
  hyprland-protocols -- Hyprland's own Wayland protocol extensions (XML)

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: github:hyprwm/hyprland-protocols/archive/refs/tags/v0.8.0.tar.gz
  ref: e41ab206d89259fdf2059fdc523c39133e23ed9efa8b0ef0de9aeed61be96e72
