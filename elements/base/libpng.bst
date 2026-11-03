kind: autotools
description: libpng -- PNG images; Plymouth draws its theme's pictures from them

build-depends:
- bootstrap/build-env.bst

depends:
- base/zlib.bst

sources:
- kind: tar
  url: sourceforge:libpng/libpng16/1.6.59/libpng-1.6.59.tar.xz
  ref: d80dd2a38a37f803cb9b6ac7b14bd6e74ddc3b654780a8380bdf93523fdb4389

variables:
  conf-local: --disable-static
