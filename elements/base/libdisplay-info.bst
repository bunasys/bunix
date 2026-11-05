kind: meson
description: |
  libdisplay-info -- parses screens' EDID and DisplayID: their modes,
  colour and HDR data (aquamarine)

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/hwdata.bst

sources:
- kind: tar
  url: https://gitlab.freedesktop.org/emersion/libdisplay-info/-/releases/0.4.0/downloads/libdisplay-info-0.4.0.tar.xz
  ref: 43b180baa143e2035654759d84e2b2f5ee77d5fe817c423838c7fe59c0d68459

variables:
  meson-local: -Dwerror=false
