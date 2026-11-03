kind: meson
description: |
  libxkbcommon -- turns key presses into characters with a keyboard layout
  from xkeyboard-config: Plymouth's keyboard now, the compositor's later

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/xkeyboard-config.bst

sources:
- kind: tar
  url: github:xkbcommon/libxkbcommon/archive/refs/tags/xkbcommon-1.13.2.tar.gz
  ref: acc4d5f7c3cbba5f9f8d08d8bdbeede84ecede46792f47929aa9321873385528

variables:
  # X11 and Wayland support, the layout registry (libxml2) and the tools
  # come with the graphics stack
  meson-local: >-
    -Denable-x11=false -Denable-wayland=false -Denable-xkbregistry=false
    -Denable-tools=false -Denable-docs=false -Denable-bash-completion=false
