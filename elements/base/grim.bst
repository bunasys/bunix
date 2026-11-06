kind: meson
description: |
  grim -- takes screenshots on Wayland (`grim shot.png`; Hyprland grants
  it the screen through wlr-screencopy): for people at the desktop, and
  for checking bunix's own screens as they really render.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/wayland-protocols.bst

depends:
- base/libjpeg-turbo.bst
- base/libpng.bst
- base/pixman.bst
- base/wayland.bst

sources:
- kind: tar
  url: https://gitlab.freedesktop.org/emersion/grim/-/archive/v1.5.0/grim-v1.5.0.tar.gz
  ref: 9e72a98f7621b1f5741b405b8dbd447acf7d300ddb12667ec526db1ce6154eaa

variables:
  meson-local: -Djpeg=enabled -Dman-pages=disabled
