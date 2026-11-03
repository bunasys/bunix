kind: meson
description: |
  libevdev -- reading input devices (keyboards, touch screens) from the
  kernel's evdev interface: Plymouth's keyboard, later libinput's devices

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: freedesktop:libevdev/libevdev-1.14.0.tar.xz
  ref: 5a0966c7110648665983848bad696c7acba614a2160d2865d535397101007332

variables:
  meson-local: -Dtests=disabled -Ddocumentation=disabled
