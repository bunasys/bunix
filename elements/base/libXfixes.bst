kind: meson
description: |
  libXfixes -- the XFIXES extension's client library, for libXcursor, which Hyprland reads cursor themes with.  X11 client
  libraries only: there is no X server (no Xwayland).

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/libX11.bst

sources:
- kind: tar
  url: xorg:individual/lib/libXfixes-6.0.2.tar.xz
  ref: 39f115d72d9c5f8111e4684164d3d68cc1fd21f9b27ff2401b08fddfc0f409ba
