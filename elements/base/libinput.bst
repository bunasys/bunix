kind: meson
description: |
  libinput -- keyboards, mice, touchpads and touch screens for the
  compositor: gestures, palm detection, acceleration, and the per-device
  quirks it ships.  libwacom (tablet identification) comes with GTK's
  libraries; until then tablets work as generic ones.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/libevdev.bst
- base/mtdev.bst
- base/systemd.bst

sources:
- kind: tar
  url: https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.32.0/libinput-1.32.0.tar.bz2
  ref: 3a6065c07b118c08d0c7b7b85a265ecb050a8cfc91eeb360890d768a51b4cce9

variables:
  meson-local: >-
    -Dudev-dir=%{prefix}/lib/udev -Dlibwacom=false -Ddebug-gui=false
    -Dtests=false -Ddocumentation=false -Dlua-plugins=disabled
    -Dzshcompletiondir=no
