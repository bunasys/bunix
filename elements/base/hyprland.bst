kind: cmake
description: |
  Hyprland -- the Wayland compositor (docs/desktop.md): tiling, touch
  gestures, animations.  Wayland only (no Xwayland); without hyprpm, its
  plugin manager (it builds plugins from git at run time), the UWSM
  session wrapper and rtkit.  The release tarball, which carries its
  udis86 and tracy subprojects.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst
- base/glaze.bst
- base/hyprland-protocols.bst
- base/hyprwayland-scanner.bst
- base/wayland-protocols.bst

depends:
- base/aquamarine.bst
- base/cairo.bst
- base/glib.bst
- base/glslang.bst
- base/hyprcursor.bst
- base/hyprgraphics.bst
- base/hyprlang.bst
- base/hyprutils.bst
# hyprctl, the command-line control tool: its IPC and line editing
- base/hyprwire.bst
- base/readline.bst
- base/lcms2.bst
- base/libcanberra.bst
- base/libdrm.bst
- base/libei.bst
- base/libinput.bst
- base/libXcursor.bst
- base/libxkbcommon.bst
- base/lua.bst
- base/mesa.bst
- base/muparser.bst
- base/pango.bst
- base/pixman.bst
- base/re2.bst
- base/systemd.bst
- base/util-linux.bst
- base/wayland.bst

sources:
- kind: tar
  url: github:hyprwm/Hyprland/releases/download/v0.57.1/source-v0.57.1.tar.gz
  ref: 24e7428f83115e58e5fc81f100f6b73691dcaaf7a503087391e44327a71c43ab

variables:
  cmake-local: >-
    -DNO_XWAYLAND=ON -DNO_HYPRPM=ON -DNO_UWSM=ON -DNO_RTKIT=ON -DBUILD_TESTING=OFF
