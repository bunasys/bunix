kind: meson
description: |
  libXrender -- the Render extension's client library, for libXcursor, which Hyprland reads cursor themes with.  X11 client
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
  url: xorg:individual/lib/libXrender-0.9.13.tar.xz
  ref: 3fe88c609df6782e1e7af2e4de36b2563d70cd70ff7dcb1cda561ad64912bb64
