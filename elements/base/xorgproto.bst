kind: meson
description: |
  xorgproto -- the X11 protocol headers, for libXcursor, which Hyprland reads cursor themes with.  X11 client
  libraries only: there is no X server (no Xwayland).

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: xorg:individual/proto/xorgproto-2026.1.tar.xz
  ref: f9bfe4a9ed8c8ab9d2a3b0d49797f046052dadd06b7a8b45dbffaffb137e8290

variables:
  meson-local: -Dlegacy=false
