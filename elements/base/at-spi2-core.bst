kind: meson
description: |
  at-spi2-core -- accessibility on the desktop: the AT-SPI bus that screen
  readers listen on, ATK, and the bridge between them.  Chromium requires
  it on Linux (Buna Browser, docs/browser.md); GTK 4 speaks AT-SPI
  itself.  Wayland only, no X11.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/python.bst

depends:
- base/dbus.bst
- base/glib.bst
- base/libxml2.bst
- base/systemd.bst

sources:
- kind: tar
  url: gnome:at-spi2-core/2.62/at-spi2-core-2.62.1.tar.xz
  ref: cca6b6a86e4389d89b370288761ce2385ddeceb10c4412da78689bc30c88af2d

variables:
  meson-local: >-
    -Dx11=disabled -Dintrospection=disabled -Ddocs=false
    -Duse_systemd=true -Ddefault_bus=dbus-daemon
