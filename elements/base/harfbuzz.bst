kind: meson
description: |
  HarfBuzz -- text shaping: turns Unicode into positioned glyphs, joining
  Arabic letters into their connected forms (pango, GTK)

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/freetype.bst
- base/glib.bst

sources:
- kind: tar
  url: github:harfbuzz/harfbuzz/releases/download/15.0.0/harfbuzz-15.0.0.tar.xz
  ref: 968536e9abd782f07f7954044c0c4020199fcdd39b41d221ec42d2a3be4a44df

variables:
  meson-local: >-
    -Dfreetype=enabled -Dglib=enabled -Dgobject=disabled -Dcairo=disabled -Dicu=disabled
    -Dchafa=disabled -Dpng=disabled -Dzlib=disabled -Dintrospection=disabled
    -Dgpu=disabled -Dgpu_demo=disabled -Dtests=disabled -Ddocs=disabled -Dutilities=disabled
