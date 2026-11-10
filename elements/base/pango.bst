kind: meson
description: |
  Pango -- lays out text in any script, right to left included, through
  HarfBuzz and FriBidi, and draws it with cairo (GTK, niri)

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/cairo.bst
- base/fontconfig.bst
- base/freetype.bst
- base/fribidi.bst
- base/glib.bst
- base/harfbuzz.bst

sources:
- kind: tar
  url: gnome:pango/1.58/pango-1.58.2.tar.xz
  ref: 342385b6ca3b7c73455d7c80a13b7dbe4489e00bc3bd4c5bd6ed4dce421e374a

variables:
  meson-local: >-
    -Dcairo=enabled -Dfontconfig=enabled -Dfreetype=enabled -Dxft=disabled -Dlibthai=disabled
    -Dintrospection=disabled -Dsysprof=disabled -Dbuild-testsuite=false -Dbuild-examples=false
    -Ddocumentation=false -Dman-pages=false
