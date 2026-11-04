kind: meson
description: |
  wayland-protocols -- the protocol extensions beyond core Wayland (xdg
  shell, layer shell, fractional scaling, ...), as XML for wayland-scanner

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/wayland.bst

sources:
- kind: tar
  url: https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.50/downloads/wayland-protocols-1.50.tar.xz
  ref: 4460c20cfcf68b994a5ee206ed15fc19ad312f16c96075186e83b0e3f4aa48a5

variables:
  meson-local: -Dtests=false
