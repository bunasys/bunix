kind: meson
description: |
  libepoxy -- finds OpenGL functions at run time (GTK's GL renderer);
  EGL only, without GLX and X11

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/python.bst

depends:
- base/mesa.bst

sources:
- kind: tar
  url: github:anholt/libepoxy/archive/refs/tags/1.5.10.tar.gz
  ref: a7ced37f4102b745ac86d6a70a9da399cc139ff168ba6b8002b4d8d43c900c15

variables:
  meson-local: -Dglx=no -Degl=yes -Dx11=false -Dtests=false -Ddocs=false
