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

config:
  # Edited in the source, before the build: the example config is both
  # installed in /usr/share/hypr and compiled in (#embed in
  # src/config/lua/DefaultConfig.hpp), and the compiled-in copy is what
  # Hyprland writes to a new user's ~/.config/hypr/hyprland.lua
  configure-commands:
    (<):
    # Its terminal is kitty; bunix's is Ghostty (base/ghostty.bst).  So
    # are the first-run hint over a new config, the safe-mode notice (in
    # English) and the terminals emergency mode tries, for a config that
    # fails to load.
    - |
      sed -i 's/^local terminal *= *"kitty"/local terminal    = "ghostty"/' example/hyprland.lua
      grep -x 'local terminal    = "ghostty"' example/hyprland.lua
      sed -i 's/SUPER+Q -> kitty (/SUPER+Q -> Ghostty (/' src/config/lua/ConfigManager.cpp
      grep -q 'SUPER+Q -> Ghostty (' src/config/lua/ConfigManager.cpp
      sed -i 's/Default keybinds apply: SUPER+Q for kitty,/Default keybinds apply: SUPER+Q for Ghostty,/' src/i18n/Engine.cpp
      grep -q 'SUPER+Q for Ghostty,' src/i18n/Engine.cpp
      sed -i 's/launch_first_installed({ "kitty",/launch_first_installed({ "ghostty", "kitty",/' src/config/lua/Emergency.hpp
      grep -q 'launch_first_installed({ "ghostty", "kitty",' src/config/lua/Emergency.hpp
    # Hyprland warns, in a banner, when its dialogs (hyprland-guiutils:
    # permission prompts, "app not responding") are missing; bunix does not
    # have them yet
    - |
      sed -i '/^        disable_hyprland_logo *=/a\        disable_hyprland_guiutils_check = true,' example/hyprland.lua
      grep -q '^        disable_hyprland_guiutils_check = true,' example/hyprland.lua
