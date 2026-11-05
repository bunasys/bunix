kind: autotools
description: libxml2 -- XML parsing (librsvg reads SVG documents with it)

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/zlib.bst
- base/xz.bst

sources:
- kind: tar
  url: gnome:libxml2/2.15/libxml2-2.15.4.tar.xz
  ref: 98087fd181d9070724f3fbc65c7377db03038eb92bd882374daff44940138821

variables:
  conf-local: --disable-static --without-python --without-icu --without-debug --with-zlib --with-lzma
