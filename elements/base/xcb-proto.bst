kind: autotools
description: |
  xcb-proto -- the X protocol in XML, which libxcb is generated from, for libXcursor, which Hyprland reads cursor themes with.  X11 client
  libraries only: there is no X server (no Xwayland).

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: xorg:individual/xcb/xcb-proto-1.17.0.tar.xz
  ref: 2c1bacd2110f4799f74de6ebb714b94cf6f80fb112316b1219480fd22562148c
