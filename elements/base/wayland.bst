kind: meson
description: |
  Wayland -- the protocol between the compositor (niri) and the
  programs it shows: libwayland-client and -server, and wayland-scanner,
  which turns protocol descriptions into C

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/expat.bst
- base/libffi.bst

sources:
- kind: tar
  url: https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.26.0/downloads/wayland-1.26.0.tar.xz
  ref: 64176eaa46e4969903e286f8e5ef8331affc17fdf03ac9b58381d2b23162b7a3

variables:
  meson-local: -Dtests=false -Ddocumentation=false -Ddtd_validation=false
