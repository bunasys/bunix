kind: autotools
description: |
  libxcb -- the X protocol C binding, for libXcursor, which Hyprland reads cursor themes with.  X11 client
  libraries only: there is no X server (no Xwayland).

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst
- base/xcb-proto.bst

depends:
- base/libXau.bst
- base/xorgproto.bst

sources:
- kind: tar
  url: xorg:individual/xcb/libxcb-1.17.0.tar.xz
  ref: 599ebf9996710fea71622e6e184f3a8ad5b43d0e5fa8c4e407123c88a59a6d55

variables:
  conf-local: --disable-static --disable-devel-docs --without-doxygen
