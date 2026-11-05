kind: meson
description: |
  GLib -- the C utility, object (GObject) and I/O (GIO) libraries GTK,
  pango, Hyprland and libinput's tools build on.  No introspection, no
  SELinux, no sysprof.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/python-packaging.bst

depends:
- base/libffi.bst
- base/pcre2.bst
- base/zlib.bst
- base/util-linux.bst

sources:
- kind: tar
  url: gnome:glib/2.90/glib-2.90.1.tar.xz
  ref: 93c941aa17d5eb1d53fe838365f29a8b4e539c222a256d974ec8f30fc413e396

variables:
  meson-local: >-
    -Dlibmount=enabled -Dselinux=disabled -Dsysprof=disabled -Dintrospection=disabled
    -Dlibelf=disabled -Dnls=disabled -Ddtrace=disabled -Dsystemtap=disabled
    -Dman-pages=disabled -Ddocumentation=false -Dtests=false -Dglib_debug=disabled
