kind: autotools
description: |
  libXcursor -- loads cursor themes (Xcursor files): Hyprland's fallback
  when a theme has no hyprcursor version.  No X server involved.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/libXrender.bst
- base/libXfixes.bst
- base/libX11.bst

sources:
- kind: tar
  url: xorg:individual/lib/libXcursor-1.2.3.tar.xz
  ref: fde9402dd4cfe79da71e2d96bb980afc5e6ff4f8a7d74c159e1966afb2b2c2c0

variables:
  conf-local: --disable-static
