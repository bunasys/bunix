kind: meson
description: |
  cage -- a Wayland compositor that shows one app, full screen, and quits
  when it does: the login screen's (base/buna-login.bst), in place of a
  whole Hyprland.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/wayland-protocols.bst

depends:
- base/wlroots.bst
- base/libxkbcommon.bst
- base/wayland.bst

sources:
- kind: tar
  url: github:cage-kiosk/cage/releases/download/v0.3.1/cage-0.3.1.tar.gz
  ref: edafc173b6f56a3e1564933e272a54aaa9fe158d330e6a415d57b44ab880fe2b

variables:
  meson-local: -Dman-pages=disabled
