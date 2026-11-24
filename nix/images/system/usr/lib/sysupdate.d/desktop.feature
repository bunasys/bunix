# The graphical system as a system extension: Mesa, libinput, fonts, niri
# with DMS and its login screen, PipeWire, Alacritty, and FUSE for
# AppImages (images/desktop.nix; after files/rootfs's).  It needs no
# other extension.  Its login screen takes tty1: `bunix ext enable
# desktop` is typed on tty2, or over SSH.
[Feature]
Description=Desktop (niri with DMS, Alacritty, AppImages)
Enabled=false
