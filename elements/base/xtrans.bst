kind: autotools
description: |
  xtrans -- X11 transport code (headers), for libXcursor, which Hyprland reads cursor themes with.  X11 client
  libraries only: there is no X server (no Xwayland).

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: xorg:individual/lib/xtrans-1.6.0.tar.xz
  ref: faafea166bf2451a173d9d593352940ec6404145c5d1da5c213423ce4d359e92
