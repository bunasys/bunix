kind: stack
description: |
  What the desktop extension is made from: the graphical system
  (docs/desktop.md, phase 3; docs/schematics.md, "Desktop or console").
  The drivers (Mesa, libinput, seatd, ALSA), Hyprland, GTK 4, Ghostty and
  the desktop's fonts.
  sysext/desktop-tree.bst keeps only what the root file system does not
  have.

depends:
- base/alsa-utils.bst
- base/ghostty.bst
- base/fonts-noto.bst
- base/hyprland.bst
- base/mesa.bst
- base/libinput.bst
- base/seatd.bst
- base/pixman.bst
- base/freetype.bst
- base/fontconfig.bst
