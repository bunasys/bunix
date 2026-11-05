kind: autotools
description: |
  libX11 -- the core X11 client library, for libXcursor, which Hyprland reads cursor themes with.  X11 client
  libraries only: there is no X server (no Xwayland).

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst
- base/xtrans.bst

depends:
- base/libxcb.bst
- base/xorgproto.bst

sources:
- kind: tar
  url: xorg:individual/lib/libX11-1.8.14.tar.xz
  ref: bbc78c46217174655c2b32b138ad119f3ac15f50808b4d0b3a2677a4b1afc950

variables:
  conf-local: --disable-static --disable-specs --without-xmlto --without-fop --without-xsltproc
