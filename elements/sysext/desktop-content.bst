kind: stack
description: |
  What the desktop extension is made from: the graphical system
  (docs/desktop.md, phase 3; docs/schematics.md, "Desktop or console").
  The drivers (Mesa, libinput, seatd, ALSA), niri with DMS, the desktop
  shell, and its login screen; GTK 4, Ghostty, Buna Browser
  (docs/browser.md) and the desktop's fonts.
  sysext/desktop-tree.bst keeps only what the root file system does not
  have.

depends:
- base/alsa-utils.bst
- base/dbus-user-session.bst
- base/pipewire.bst
- base/wireplumber.bst
- base/ghostty.bst
- base/buna-browser.bst
- base/greetd.bst
- desktop/dms-greeter.bst
- desktop/dms.bst
- desktop/accountsservice.bst
- desktop/niri.bst
- base/grim.bst
- base/fonts-noto.bst
# gdk-pixbuf's SVG loader, which GTK draws SVG icons with
# (sysext/desktop-tree.bst checks it is there)
- base/librsvg.bst
- base/mesa.bst
- base/libinput.bst
- base/seatd.bst
- base/pixman.bst
- base/freetype.bst
- base/fontconfig.bst
