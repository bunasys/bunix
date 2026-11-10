kind: meson
description: |
  cairo -- 2D vector drawing (pango, GTK, niri, librsvg).  Image
  surfaces, FreeType and Fontconfig fonts, PNG; no X11.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/fontconfig.bst
- base/freetype.bst
- base/glib.bst
- base/libpng.bst
- base/pixman.bst
- base/zlib.bst

sources:
- kind: tar
  url: https://www.cairographics.org/releases/cairo-1.18.6.tar.xz
  ref: 1c767308174337a74694da0f3ec069c271452163a1ef4540964c50c301f157d4

variables:
  meson-local: >-
    -Dfreetype=enabled -Dfontconfig=enabled -Dpng=enabled -Dzlib=enabled -Dglib=enabled
    -Dxlib=disabled -Dxcb=disabled -Dtee=disabled -Dlzo=disabled -Dspectre=disabled
    -Dsymbol-lookup=disabled -Ddwrite=disabled -Dtests=disabled
