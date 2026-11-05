kind: meson
description: |
  libei -- emulated input: how a program asks the compositor to press keys
  or move the pointer (Hyprland's input capture, remote desktop)

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/python-jinja2.bst

depends:
- base/systemd.bst

sources:
- kind: tar
  url: https://gitlab.freedesktop.org/libinput/libei/-/archive/1.6.0/libei-1.6.0.tar.bz2
  ref: 5ed6078fa63afd554cc04b1001675615da0ed8fe23b80492ab63403140b5a830

variables:
  meson-local: -Dtests=disabled -Ddocumentation=[] -Dsd-bus-provider=libsystemd -Dliboeffis=disabled
