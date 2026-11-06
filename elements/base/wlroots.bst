kind: meson
description: |
  wlroots -- the library small Wayland compositors are built on: screens
  (DRM/KMS), input (libinput), a session through libseat, and an OpenGL ES
  renderer.  For cage, the login screen's compositor (base/cage.bst);
  Hyprland has its own (base/aquamarine.bst).  Without X11 (Xwayland or
  the X11 backend) and Vulkan.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/hwdata.bst
- base/wayland-protocols.bst

depends:
- base/libdisplay-info.bst
- base/libdrm.bst
- base/libinput.bst
- base/libxkbcommon.bst
- base/lcms2.bst
- base/mesa.bst
- base/pixman.bst
- base/seatd.bst
- base/systemd.bst
- base/wayland.bst

sources:
- kind: tar
  url: https://gitlab.freedesktop.org/wlroots/wlroots/-/releases/0.20.2/downloads/wlroots-0.20.2.tar.gz
  ref: 80c567d2ed4efb2cfa6b077f22c7a710d9c78ba4e185a75e8694001114af0733

variables:
  meson-local: >-
    -Dxwayland=disabled -Dxcb-errors=disabled -Dlibliftoff=disabled
    -Dbackends=drm,libinput -Drenderers=gles2 -Dallocators=gbm
    -Dsession=enabled -Dcolor-management=enabled -Dexamples=false
