kind: meson
description: |
  libadwaita -- GNOME's widgets and style on top of GTK 4 (Ghostty's
  windows, tabs and dialogs); its stylesheet comes compiled in the release
  tarball, which also bundles ministream, linked in statically

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/python.bst
- base/gettext.bst

depends:
- base/fribidi.bst
- base/glib.bst
- base/gtk4.bst

sources:
- kind: tar
  url: gnome:libadwaita/1.10/libadwaita-1.10.0.tar.xz
  ref: b1bf56239269d101a6391ad4553c910eff9cc6170b803916405477ef60a66c84

variables:
  meson-local: >-
    -Dintrospection=disabled -Dvapi=false -Ddocumentation=false -Dtests=false -Dexamples=false
