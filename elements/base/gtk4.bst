kind: meson
description: |
  GTK 4 -- the toolkit of Ghostty and of bunix's own screens (docs/
  desktop.md): Wayland only, drawn with OpenGL ES through libepoxy.
  Without X11, Vulkan, GStreamer media, printing, the demos and tests.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/python.bst
- base/gettext.bst
- base/wayland-protocols.bst

depends:
- base/cairo.bst
- base/fontconfig.bst
- base/freetype.bst
- base/fribidi.bst
- base/gdk-pixbuf.bst
- base/glib.bst
- base/graphene.bst
- base/harfbuzz.bst
- base/libdrm.bst
- base/libepoxy.bst
- base/libjpeg-turbo.bst
- base/libpng.bst
- base/libtiff.bst
- base/libxkbcommon.bst
- base/mesa.bst
- base/pango.bst
- base/wayland.bst

sources:
- kind: tar
  url: gnome:gtk/4.24/gtk-4.24.1.tar.xz
  ref: e98abe720e16129c8c0f50761dee0a2e9ae2478055e31018f6cf977fcf6513e9

variables:
  meson-local: >-
    -Dx11-backend=false -Dwayland-backend=true -Dbroadway-backend=false
    -Dmedia-gstreamer=disabled -Dprint-cups=disabled -Dprint-cpdb=disabled -Dvulkan=disabled
    -Dcloudproviders=disabled -Dsysprof=disabled -Dtracker=disabled -Dcolord=disabled
    -Daccesskit=disabled -Dintrospection=disabled -Ddocumentation=false -Dman-pages=false
    -Dbuild-demos=false -Dbuild-testsuite=false -Dbuild-examples=false -Dbuild-tests=false
