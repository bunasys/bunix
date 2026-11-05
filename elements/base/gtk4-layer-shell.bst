kind: meson
description: |
  gtk4-layer-shell -- lets a GTK 4 window be a layer of the desktop (wlr
  layer-shell): Ghostty's quick terminal, which drops down from the top

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/wayland-protocols.bst

depends:
- base/gtk4.bst
- base/wayland.bst

sources:
- kind: tar
  url: github:wmww/gtk4-layer-shell/archive/refs/tags/v1.3.0.tar.gz
  ref: 1ebb01ab14e98afd1727f68f64981c37bd23305b1f131f5667c02b94cf593192

variables:
  meson-local: >-
    -Dintrospection=false -Dvapi=false -Ddocs=false -Dtests=false -Dsmoke-tests=false -Dexamples=false
