# The desktop extension: the graphical system, which a machine has when
# its person chooses a desktop and not a console (docs/desktop.md; after
# elements/sysext/desktop*.bst).  So far the drivers -- Mesa, libinput,
# seatd -- the text stack and its fonts, niri, the compositor, and the
# shell: DMS on Quickshell and Qt 6, with its login screen under greetd,
# the list of people (accountsservice) and each one's session bus.  Sound
# and the terminal come next.  It needs no other extension.
#
#   nix-build /bunix/nix/images/desktop.nix -A image
#
#   signature, version
#           as images/extension.nix takes them
{ system ? builtins.currentSystem, signature ? null, version ? import ../release.nix }:

let
  desktop = import ../desktop.nix { inherit system; };
  extension = import ./extension.nix { inherit system signature version; };
in
extension {
  name = "desktop";
  contents = [
    desktop.mesa desktop.libinput desktop.seatd desktop.fontconfig desktop.fonts desktop.niri
    desktop.dms desktop.dms-greeter desktop.greetd desktop.accountsservice desktop.dbus-user-session
  ];
  # Programs of what these need to run that are for building software
  # against them, not for a desktop.  And libinput's tools that are
  # Python, which the system does not have: `libinput measure`,
  # `analyze`, `replay` and `list-kernel-devices` (its others are C, and
  # stay).
  without = [
    "bin/wayland-scanner" "bin/libpng-config" "bin/libpng16-config"
    "lib/libinput/libinput-analyze-buttons" "lib/libinput/libinput-analyze-per-slot-delta"
    "lib/libinput/libinput-analyze-recording" "lib/libinput/libinput-analyze-touch-down-state"
    "lib/libinput/libinput-list-kernel-devices" "lib/libinput/libinput-measure-fuzz"
    "lib/libinput/libinput-measure-touch-size" "lib/libinput/libinput-measure-touchpad-pressure"
    "lib/libinput/libinput-measure-touchpad-size" "lib/libinput/libinput-measure-touchpad-tap"
    "lib/libinput/libinput-replay"
  ];
}
