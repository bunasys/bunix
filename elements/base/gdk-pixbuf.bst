kind: meson
description: |
  gdk-pixbuf -- image loading for GTK: PNG and JPEG built in.  Without
  glycin (sandboxed Rust loaders) for now, and recognising images by
  their own signatures, not through shared-mime-info's database.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/glib.bst
- base/libjpeg-turbo.bst
- base/libpng.bst

sources:
- kind: tar
  url: gnome:gdk-pixbuf/2.44/gdk-pixbuf-2.44.8.tar.xz
  ref: 919f529512961a12e81cd4b4b466a48c3933469e7f9a310c6513cd4fb252ba3c

variables:
  meson-local: >-
    -Dpng=enabled -Djpeg=enabled -Dtiff=disabled -Dgif=enabled -Dglycin=disabled
    -Dothers=disabled -Dthumbnailer=disabled -Dgio_sniffing=false -Dintrospection=disabled -Dman=false
    -Ddocumentation=false -Dtests=false -Dinstalled_tests=false
