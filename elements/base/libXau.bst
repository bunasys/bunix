kind: meson
description: |
  libXau -- X11 authorization, for libXcursor, which Hyprland reads cursor themes with.  X11 client
  libraries only: there is no X server (no Xwayland).

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/xorgproto.bst

sources:
- kind: tar
  url: xorg:individual/lib/libXau-1.0.12.tar.xz
  ref: 74d0e4dfa3d39ad8939e99bda37f5967aba528211076828464d2777d477fc0fb
