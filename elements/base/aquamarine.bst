kind: cmake
description: |
  aquamarine -- Hyprland's rendering backend: DRM/KMS screens, libinput
  input and a session through libseat

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst
- base/hyprwayland-scanner.bst
- base/wayland-protocols.bst
- base/hwdata.bst

depends:
- base/hyprutils.bst
- base/libinput.bst
- base/seatd.bst
- base/wayland.bst
- base/pixman.bst
- base/libdrm.bst
- base/mesa.bst
- base/systemd.bst
- base/libdisplay-info.bst

sources:
- kind: tar
  url: github:hyprwm/aquamarine/archive/refs/tags/v0.16.0.tar.gz
  ref: 42339c3096c9de6582c0d71bc86b7e63334a3faf6a2b917d385ad093caf66c3c

variables:
  cmake-local: -DBUILD_TESTING=OFF
