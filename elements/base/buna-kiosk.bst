kind: cargo
description: |
  buna-kiosk -- bunix's own kiosk compositor (src/buna-kiosk, docs/kiosk.md):
  one app full screen, on aquamarine, the screens-and-input library
  Hyprland uses.  Phase 1: it takes the screens, fills them with the login
  screen's background, follows VT switches, and leaves the picture lit
  when it exits.  A C++ shim (src/buna-kiosk/shim) is the only code that
  calls aquamarine.

build-depends:
- bootstrap/build-env.bst
- bootstrap/rust.bst
- base/pkgconf.bst

depends:
- base/aquamarine.bst
- base/hyprutils.bst
- base/pixman.bst
- base/libdrm.bst
- base/mesa.bst

sources:
- kind: local
  path: src/buna-kiosk
