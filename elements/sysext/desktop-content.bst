kind: stack
description: |
  What the desktop extension is made from: the graphical system
  (docs/desktop.md, phase 3; docs/schematics.md, "Desktop or console").
  Grows with each step: the drivers (Mesa, libinput, seatd, the font
  libraries), then Hyprland, then GTK4 and Ghostty.
  sysext/desktop-tree.bst keeps only what the root file system does not
  have.

depends:
- base/hyprland.bst
- base/mesa.bst
- base/libinput.bst
- base/seatd.bst
- base/pixman.bst
- base/freetype.bst
- base/fontconfig.bst
